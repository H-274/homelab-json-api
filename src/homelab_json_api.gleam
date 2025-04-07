import app/router
import app/web
import envoy
import gleam/erlang/process
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  let secret_key_base = wisp.random_string(64)

  let assert Ok(token) = envoy.get("TOKEN")
  let assert Ok(jellyseerr_url) = envoy.get("JELLYSEERR_URL")
  let assert Ok(jellyseerr_api_key) = envoy.get("JELLYSEERR_API_KEY")

  let ctx = web.Context(token:, jellyseerr_url:, jellyseerr_api_key:)
  let handle_req = router.handle_request(_, ctx)

  let assert Ok(_) =
    wisp_mist.handler(handle_req, secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}
