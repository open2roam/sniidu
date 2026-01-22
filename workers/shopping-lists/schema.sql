-- D1 Schema for shared shopping lists
-- This runs on Cloudflare's edge SQLite (D1)

-- Shopping lists
CREATE TABLE IF NOT EXISTS shopping_lists (
    id TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT DEFAULT '',
    shared INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

-- Shopping list items
CREATE TABLE IF NOT EXISTS shopping_list_items (
    id TEXT PRIMARY KEY,
    list_id TEXT NOT NULL REFERENCES shopping_lists(id) ON DELETE CASCADE,
    product_id TEXT DEFAULT '',
    name TEXT NOT NULL,
    quantity INTEGER DEFAULT 1,
    checked INTEGER DEFAULT 0
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_lists_owner ON shopping_lists(owner_id);
CREATE INDEX IF NOT EXISTS idx_lists_shared ON shopping_lists(shared);
CREATE INDEX IF NOT EXISTS idx_items_list ON shopping_list_items(list_id);
CREATE INDEX IF NOT EXISTS idx_items_checked ON shopping_list_items(list_id, checked);
