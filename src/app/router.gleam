import app/web
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: web.Context) -> Response {
  use req <- web.middleware(req, ctx)

  case wisp.path_segments(req) {
    ["/jellyseer/requests"] -> jellyseer_requests(req, ctx)

    _ -> wisp.not_found()
  }
}

fn jellyseer_requests(req, ctx) {
  todo
}
