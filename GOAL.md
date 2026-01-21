## Starting point

* 2 domains in Cloudflare open2log.com and opentolog.com
* 1 auction server in Hetzner robot
* 1 bx11 1Tb storagebox in Hetzner cloud

## Principles

* Use devenv.nix file to manage the tools that you need, do not install them with homebrew or directly with curl
* You need to use terraform and sops to manage the cloud resources.
* You need to use NixOS to manage the server.
* If you will need to build cloudflare workers built them with Rust.
* You need to use duckdb for downloading/transforming/querying data.
* If certain thing can't yet be done with duckdb search for suitable duckdb extensions or interrupt and ask for help from the user.
* You don't want to expose the IP-address of the server.
* Use gluetun proxy to crawl the sites so that we don't expose the IP-address of the server.
* Server should have firewall rules which block outside access
* Server should be sitting behind Cloudflare so that we don't expose the IP-address and that we can leverage the caching in Cloudflare

## Goal

* Setup a crawling pipelines for grocery product data
* Serve that product data with elixir/phoenix based app
* Interact with duckdb in Elixir using: https://github.com/midwork-finds-jobs/ecto_duckdb
* Setup a sqlite file in the server with ducklake and webdavfs so that parquet files will be stored in the Hetzner storagebox
* Stream changes to that sqlite file with for example with litestream.io so that all data is easily accessible from the Hetzner storagebox.
* Setup a read only user for the storagebox to allow access for the ducklake
* Build iOS application which can access the grocery data from the storagebox. By default it should show a map using overturemaps data. It should show what are the nearest shops and how long walking/bicycling/driving distance away they are.
* If user is few meters away from a shop show a popup if they are in eg Lidl Tampere and user can confirm this.
* Allow user to scan product barcodes and pictures of the prices of the products. These will be hopefully already be parsed with a local AI model or OCR so that we can send the barcode and the price to the server. In addition add timestamp of when it was scanned and the overturemaps GERS id of the shop where the user was.
* Crop the barcode image from the product and encode it to AVIF and send that AVIF file to the server (Use R2 signed requests to upload the image directly to the R2 bucket)
* Also crop the product price image and encode to AVIF and send it to the server in similar manner to R2
* Ask user also to take a picture of the product if we didn't have one already.
* These images should be stored in offline database in the phone. If there's no connection they will be uploaded later.
* Allow user to select option to only update the price data when they are connected to wifi. Also allow them to download offline navigation tiles / weather / product data for their local area eg few kilometers radius
* If the crawled data from online doesn't contain bar code we need to be able to suggest the user what online product this would match and they can give their vote. Once we have enough votes we can automatically match online product and physical product.
* You should store AVIF version of the crawled product images into hetzner storagebox if you can.
* When the system has more products let's add shopping list feature. Main idea is to collect enough data and build network of products which can substitute each other. Let users vote which product can substitute other product in a different shop. Then in the end the user should know how much their shopping list costs in different shops and how big percent of items can be found from that shop. Allow users to have different shopping lists. Allow them to have online shopping lists which work offline but which they can sync to each other. If the shopping list is shared it should be stored in D1 database in Cloudflare.
* If the server can't respond for the requests of adding more products from the offline database try again later. Add rate limiting per IP-address for adding new products. Do the rate-limiting on Cloudflare with terraform instead of the server itself
* This app requires registration and agreeing on privacy policy.
* For now don't allow users to directly join. They can create a user and sign up for a waiting list and when we have tested everything and enough capacity they will get a notification that they can start using the app.
* You want to explore more grocery stores first in Finland, then in Nordics and Baltics and then the rest of the Europe. Eventually this should cover the whole world.
* Later on build ability to add/scan fuel prices from the stations.

## Opentofu
### Hetzner auction servers
We have created a custom provider for opentofu to manage hetzner hrobot resources. See more in: https://registry.terraform.io/providers/midwork-finds-jobs/hrobot/latest/docs

If you can't do something you want you can create issues in: https://github.com/midwork-finds-jobs/terraform-provider-hrobot

## DuckDB
Use the following duckdb community extensions. We manage the source code for each of these and you can create issues in their github repositories if they are not enough for what you are building.

### Valhalla routing
Extension to create valhalla compatible routing tiles (expensive operation).

When the tiles are built it allows navigating with those routing files.

This is useful so we don't need to rely on apple or google for routing.

You need to use the tiles to help users to answer how long it will take for them to go to a certain grocery store.

Source: https://github.com/midwork-finds-jobs/duckdb-valhalla-routing

### Weather
Extension to build parquet files with global weather parquet files with h3 lookup. You need to use this if it's raining so that you can show it to the user when they are deciding on where to go.

Source: https://github.com/onnimonni/duckdb-weather

### Crawling
Extension to crawl websites and the product data that they have. Main targets are finnish grocery stores like s-kaupat.fi, tokmanni.fi and lidl.fi. Also crawl lidl prices all over the europe for all tlds you can find.

The crawling extension modifies duckdb quite heavily and introduces long running processes which can be interrupted. It can discover sitemap.xml automatically and extract javascript variables from the pages if needed to.

Ideally you would iterate the discover() function it has to make it easier for you to find interesting data on the websites without wasting lot of tokens on the full html.

Source: https://github.com/midwork-finds-jobs/duckdb-crawler


## Ideas to consider for later
* We don't yet have access to public transportation data so it's harder to give travel estimates with buses
* We don't yet have elevation data for Valhalla routing so the travel estimates are not as good as they could be
* We might want to explore duckdb module for sqlite which writes WAL log directly into the storagebox. Storagebox supports append operation with sshfs and it might be a good idea to only send the diff instead of completely wiping the ducklake file everytime something changes.
* Build integration to LHV bank account to read payments from members. This is a non-profit organization and we don't have paying users. There's only members who are contributing some monthly/yearly fee. We might build certain features only for NGO members in the future.
* Build integration for Merit accounting: https://www.merit.ee/en/
* Build integration with EMTA to file monthly taxes for the NGO
* Build Android App as well.


## How does this system sustain itself?
Searching for products and adding products can be done by anyone who registers to the app (once the waiting list phase is over) but only the NGO members can use the shopping list feature. Initial membership fee is 2€ per month and initially it can only be paid by direct recurring IBAN transfers. to our bank account. Every member should get their own bank reference which they can use to pay for the membership.

The membership fees are used to pay for the server costs and maintenance and development of the service. The extra money that we collect will go to projects/charities which will help save more and more of precious time for the mankind. We can't decide what people will do with their added free time but we can hopefully reduce the amount of time which goes to stupid things like price comparisons. This clear visibility should also pressure the grocery chains to compete with their pricing so it's good for the consumers. Let's automate what we can with good algorhitms and by sharing the knowledge.

Price and other data that the system will collect can be used for research and other purposes.

Reach out to us if you want to sponsor the project.