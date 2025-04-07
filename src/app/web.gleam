import gleam/list
import wisp

pub type Context {
  Context(token: String, jellyseerr_url: String, jellyseerr_api_key: String)
}

pub fn middleware(
  req: wisp.Request,
  ctx: Context,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  use <- require_auth(req, ctx)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  handle_request(req)
}

fn require_auth(req: wisp.Request, ctx: Context, next) {
  case list.key_find(req.headers, "Authorization") {
    Ok(token) if token == ctx.token -> next()

    Ok(_) -> wisp.response(403) |> wisp.string_body("Forbidden")
    Error(_) -> wisp.response(401) |> wisp.string_body("Unauthorized")
  }
}
