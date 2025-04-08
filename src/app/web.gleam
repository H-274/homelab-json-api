import birl
import gleam/int
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
  use <- wisp.log_request(req)
  use <- request_duration()
  use <- require_auth(req, ctx)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  handle_request(req)
}

fn require_auth(req: wisp.Request, ctx: Context, handler) {
  case list.key_find(req.headers, "authorization") {
    Ok(token) if token == ctx.token -> handler()

    Ok(_) -> wisp.response(403) |> wisp.string_body("Forbidden")
    Error(_) -> wisp.response(401) |> wisp.string_body("Unauthorized")
  }
}

fn request_duration(handler) {
  let start_time = birl.to_unix_milli(birl.now())
  let response = handler()
  let end_time = birl.to_unix_milli(birl.now())

  let duration_string = int.to_string(end_time - start_time) <> " ms"
  wisp.log_info("Request completed in: " <> duration_string)

  response
}
