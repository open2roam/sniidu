use worker::*;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
struct ShoppingList {
    id: String,
    owner_id: String,
    name: String,
    description: Option<String>,
    shared: bool,
    created_at: String,
    updated_at: String,
}

#[derive(Serialize, Deserialize, Debug)]
struct ShoppingListItem {
    id: String,
    list_id: String,
    product_id: Option<String>,
    name: String,
    quantity: i32,
    checked: bool,
}

#[derive(Deserialize)]
struct CreateListRequest {
    name: String,
    description: Option<String>,
    shared: Option<bool>,
}

#[derive(Deserialize)]
struct AddItemRequest {
    product_id: Option<String>,
    name: String,
    quantity: Option<i32>,
}

fn get_user_id(req: &Request) -> Result<String> {
    req.headers()
        .get("X-User-Id")?
        .ok_or_else(|| Error::RustError("Missing user ID".into()))
}

#[event(fetch, respond_with_errors)]
pub async fn main(req: Request, env: Env, _ctx: Context) -> Result<Response> {
    Router::new()
        .get("/health", |_, _| Response::ok("OK"))
        .get_async("/lists", |req, ctx| async move {
            let user_id = get_user_id(&req)?;
            let d1 = ctx.env.d1("DB")?;

            let stmt = d1.prepare(
                "SELECT id, owner_id, name, description, shared, created_at, updated_at
                 FROM shopping_lists
                 WHERE owner_id = ?1 OR shared = 1
                 ORDER BY updated_at DESC"
            );
            let results = stmt.bind(&[user_id.into()])?.all().await?;
            let lists: Vec<ShoppingList> = results.results()?;

            Response::from_json(&serde_json::json!({ "data": lists }))
        })
        .get_async("/lists/:id", |req, ctx| async move {
            let user_id = get_user_id(&req)?;
            let list_id = ctx.param("id").unwrap();
            let d1 = ctx.env.d1("DB")?;

            // Get list
            let stmt = d1.prepare(
                "SELECT id, owner_id, name, description, shared, created_at, updated_at
                 FROM shopping_lists
                 WHERE id = ?1 AND (owner_id = ?2 OR shared = 1)"
            );
            let list: Option<ShoppingList> = stmt
                .bind(&[list_id.into(), user_id.into()])?
                .first(None)
                .await?;

            match list {
                Some(l) => {
                    // Get items
                    let items_stmt = d1.prepare(
                        "SELECT id, list_id, product_id, name, quantity, checked
                         FROM shopping_list_items
                         WHERE list_id = ?1
                         ORDER BY checked, name"
                    );
                    let items: Vec<ShoppingListItem> = items_stmt
                        .bind(&[l.id.clone().into()])?
                        .all()
                        .await?
                        .results()?;

                    Response::from_json(&serde_json::json!({
                        "data": {
                            "list": l,
                            "items": items
                        }
                    }))
                }
                None => Response::error("Not found", 404),
            }
        })
        .post_async("/lists", |mut req, ctx| async move {
            let user_id = get_user_id(&req)?;
            let body: CreateListRequest = req.json().await?;
            let d1 = ctx.env.d1("DB")?;

            let id = uuid_v4();
            let now = chrono_now();
            let shared = body.shared.unwrap_or(false);

            let stmt = d1.prepare(
                "INSERT INTO shopping_lists (id, owner_id, name, description, shared, created_at, updated_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)"
            );
            stmt.bind(&[
                id.clone().into(),
                user_id.into(),
                body.name.clone().into(),
                body.description.clone().unwrap_or_default().into(),
                shared.into(),
                now.clone().into(),
                now.into(),
            ])?
            .run()
            .await?;

            Response::from_json(&serde_json::json!({
                "data": {
                    "id": id,
                    "name": body.name,
                    "shared": shared
                }
            }))
        })
        .post_async("/lists/:id/items", |mut req, ctx| async move {
            let user_id = get_user_id(&req)?;
            let list_id = ctx.param("id").unwrap();
            let body: AddItemRequest = req.json().await?;
            let d1 = ctx.env.d1("DB")?;

            // Verify access
            let check = d1.prepare(
                "SELECT id FROM shopping_lists WHERE id = ?1 AND (owner_id = ?2 OR shared = 1)"
            );
            let exists: Option<ShoppingList> = check
                .bind(&[list_id.clone().into(), user_id.into()])?
                .first(None)
                .await?;

            if exists.is_none() {
                return Response::error("Not found", 404);
            }

            let item_id = uuid_v4();
            let quantity = body.quantity.unwrap_or(1);

            let stmt = d1.prepare(
                "INSERT INTO shopping_list_items (id, list_id, product_id, name, quantity, checked)
                 VALUES (?1, ?2, ?3, ?4, ?5, 0)"
            );
            stmt.bind(&[
                item_id.clone().into(),
                list_id.into(),
                body.product_id.clone().unwrap_or_default().into(),
                body.name.clone().into(),
                quantity.into(),
            ])?
            .run()
            .await?;

            // Update list timestamp
            let update = d1.prepare("UPDATE shopping_lists SET updated_at = ?1 WHERE id = ?2");
            update.bind(&[chrono_now().into(), list_id.into()])?.run().await?;

            Response::from_json(&serde_json::json!({
                "data": {
                    "id": item_id,
                    "name": body.name,
                    "quantity": quantity
                }
            }))
        })
        .delete_async("/lists/:id", |req, ctx| async move {
            let user_id = get_user_id(&req)?;
            let list_id = ctx.param("id").unwrap();
            let d1 = ctx.env.d1("DB")?;

            // Only owner can delete
            let stmt = d1.prepare("DELETE FROM shopping_lists WHERE id = ?1 AND owner_id = ?2");
            stmt.bind(&[list_id.into(), user_id.into()])?.run().await?;

            Response::empty()
        })
        .run(req, env)
        .await
}

fn uuid_v4() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    format!("{:032x}", now)
}

fn chrono_now() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();
    format!("{}", secs)
}
