# Ghostfolio-Sync

[![Docker Hub package][dockerhub-badge]][dockerhub-link]

[dockerhub-badge]: https://img.shields.io/badge/images%20on-Docker%20Hub-blue.svg
[dockerhub-link]: https://hub.docker.com/repository/docker/agusalex/ghostfolio-sync "Docker Hub Image"

Sync your Ghostfolio with IBKR 
( more to come? Help is always welcome! )


## Setup

### IBKR
**Important**:  When you configure your Flex Query give it:
* Account Information: Currency
* Cash Report: Currency, Ending Cash
* Trades: Select All (however there is a risk new IBKR fields will cause issues)
* Change in Dividend Accruals: Select All (required to sync dividends)

> **Required for de-duplication:** make sure your Trades section includes **Trade ID**, **Transaction ID** and **IB Order ID**. This tool writes the IBKR trade id into each Ghostfolio activity's comment (`tradeID=...`) and uses it to detect what has already been synced. If none of those id fields are present, the same trades may be re-imported on every run.

Follow this guide to configure your Flex Queries in your Interactive Brokers account:
[https://portfellow.com/how-to-configure-ib-import](https://portfellow.com/how-to-configure-ib-import)

> **Note on the IBKR endpoint:** IBKR retired `gdcdyn.interactivebrokers.com` and the legacy `/Universal/servlet/FlexStatementService` path. This tool forces all Flex Web Service calls to the current host `ndcdyn.interactivebrokers.com/AccountManagement/FlexWebService`, even if IBKR returns a legacy URL in its response. No action needed on your side.

**Important: If you dont want ghostfolio-sync to sync everything everytime and make it quicker, just set a shorter window for the query. Keep in mind that what was not synced by ghostfolio-sync in that period of time will be lost (ie when the window moves and content was not uploaded to ghostfolio). This can be avoided at the cost of a longer window of time and longer sync**

### Ghostfolio

> **Compatibility:** Ghostfolio **3.5.0** (2026-05-24) removed the old `/api/v1/order` endpoint in favour of `/api/v1/activities`. This tool uses `/api/v1/activities` and automatically falls back to `/api/v1/order` on older instances, so it works on both. If you are on an in-between version, no change is needed.

* Take note of your user **KEY** (generated upon user creation and used to login to Ghostfolio)
* Run the following on the terminal (replace `ghostfol.io` with `localhost` or your host url if you are self-hosting):

```
curl -X POST -H "Content-Type: application/json" \
	-d '{ "accessToken": "YOUR-USER-KEY-GOES-HERE }' \    
	https://ghostfol.io/api/v1/auth/anonymous
```

* Take note of the token `{"authToken":"12cd45...`. That is your **GHOST_TOKEN**

## Run in Docker

```docker run -e IBKR_ACCOUNT_ID=$IBKR_ACCOUNT_ID -e GHOST_TOKEN=YOUR_GHOST_TOKEN -e IBKR_TOKEN=YOUR-IBKR-TOKEN -e IBKR_QUERY=YOUR-IBKR-QUERY agusalex/ghostfolio-sync```

In Podman

```podman run -e IBKR_ACCOUNT_ID=$IBKR_ACCOUNT_ID -e GHOST_TOKEN=YOUR_GHOST_TOKEN -e IBKR_TOKEN=$IBKR_TOKEN -e IBKR_QUERY=$IBKR_QUERY -e GHOST_HOST=http://$GHOST_URL -e GHOST_CURRENCY=EUR -e GHOST_IBKR_PLATFORM=$IBKR_PLATFORM -v ./mapping.yaml:/usr/app/src/mapping.yaml:Z agusalex/ghostfolio-sync```

### Symbol mapping

You can specify the symbol mappings in `mapping.yaml` and you do not need to rebuild the container with the above mount command.


### More Options
| Envs | Mutiple ( Comma-separated ) | Description  |
|--|--|--|
|**IBKR_ACCOUNT_ID**  |Yes| Your IBKR Account ID (Example: U7649433) |
|**IBKR_TOKEN**   |Yes| Your Token  |
|**IBKR_QUERY**   |Yes| Your Query ID |
|**GHOST_TOKEN**   |Yes| The token for your ghostfolio account |
|**GHOST_KEY**   |Yes| The key for your ghostfolio account, if this is used you don't need **GHOST_TOKEN** and vice-versa |
|**GHOST_HOST**   |Yes| (optional) Ghostfolio Host, only add if using custom ghostfolio |
|**GHOST_CURRENCY**   |Yes| (optional) Ghostfolio Account Currency, only applied if the account doesn't exist |
|**GHOST_IBKR_PLATFORM**  |Yes| (optional) For self-hosted, specify the Platform ID |
|**CRON**  |No| (optional) To run on a [Cron Schedule](https://crontab.guru/). Use a sensible interval such as `0 * * * *` (hourly) or `0 6 * * *` (daily) — **do not** use `* * * * *` (every minute), IBKR rate-limits the Flex service. |
|**OPERATION**  |Yes| (optional) One of: `SYNCIBKR` (default, syncs trades + dividends), `GET_ALL_ACTS` (prints all activities), `DELETE_ALL_ACTS` (erases all activities of the account) |

### Configuring / Retrieving Platform ID

If you are using ghostfolio self-hosted option, you need to go into Ghostfolio and add a platform for IBKR.

Then make a request to `/account` to find the relevant platform ID and store it in the IBKR_PLATFORM env variable

```bash
curl "http://10.0.0.2:3333/api/v1/account" \
     -H "Authorization: Bearer $GHOST_TOKEN"

export IBKR_PLATFORM=<PUT PLATFORM ID HERE>
```

## What gets synced

* **Trades** — stock buys/sells (`OPEN`, `CLOSE`, `OPENCLOSE`). Non-stock asset categories (options, futures, forex, etc.) are skipped.
* **Dividends** — cash dividends from Change in Dividend Accruals.
* **Cash balance** — the account's base-currency ending cash.

Each activity is tagged with `tradeID=<id>` in its comment so re-running the sync does not create duplicates.

## Troubleshooting

* **Activities are duplicated on every sync** — the tool de-duplicates by reading existing activities back from Ghostfolio and matching the `tradeID=...` comment. Check the sync log for the `Dedup:` lines:
  * `Dedup: fetched N existing activities, M carry a usable tradeID` — if `N` is `0` on an account that already has activities, the read endpoint is failing (see Compatibility note above) or auth is wrong.
  * `... new activities lack a usable tradeID ...` — your Flex Query is missing the Trade ID / Transaction ID / IB Order ID columns (see the IBKR section).
  * After a clean run you should see `Nothing new to sync`. To clear duplicates already created, run once with `OPERATION=DELETE_ALL_ACTS`, then sync again.
* **`Failed to resolve 'gdcdyn.interactivebrokers.com'` / DNS errors** — a network/DNS problem on the host running the container, not a code issue. Ensure the container can resolve public hostnames (e.g. `docker run --dns 1.1.1.1 --dns 8.8.8.8 ...`).
* **`No bearer token provided`** — set either `GHOST_TOKEN` or `GHOST_KEY`.

## Contributing

* Feel free to submit any issue or PR's you think necessary
* If you like the work and want to buy me a coffee you are more than welcome :)

<a href="https://www.buymeacoffee.com/YiQkYsghUQ" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>
