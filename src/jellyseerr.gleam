import app/web
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/otp/task
import wisp

pub type RequestInfo {
  RequestInfo(media_type: MediaType, tmdb_id: Int, requested_by: String)
}

pub type MediaType {
  Movie
  Tv
}

pub fn handle(ctx: web.Context) {
  case fetch_data(ctx) {
    Ok(_) -> todo

    _ -> wisp.internal_server_error() |> wisp.string_body("Unexpected error")
  }
}

fn fetch_data(ctx: web.Context) {
  let assert Ok(req) = request.to(ctx.jellyseerr_url <> "/api/v1/request")
  let req =
    request.set_header(req, "X-Api-Key", ctx.jellyseerr_api_key)
    |> request.set_query([
      #("take", "10"),
      #("sort", "added"),
      #("sortDirection", "desc"),
    ])

  let assert Ok(res) = httpc.send(req)
  let assert Ok(requests_info) =
    json.parse(
      res.body,
      decode.at(["results"], decode.list(request_info_decoder())),
    )

  let _media_info =
    list.map(requests_info, fn(req_info) {
      process.sleep(100)
      use <- task.async()
      let assert Ok(req) =
        request.to(
          ctx.jellyseerr_url
          <> "/api/v1/movie/"
          <> int.to_string(req_info.tmdb_id),
        )
      let assert Ok(res) = httpc.send(req)
      let assert Ok(media_info) = json.parse(res.body, todo)

      media_info
    })

  todo
}

fn request_info_decoder() -> decode.Decoder(RequestInfo) {
  use media_type <- decode.field("type", media_type_decoder())
  use tmdb_id <- decode.subfield(["media", "tmdbId"], decode.int)
  use requested_by <- decode.subfield(
    ["requestedBy", "displayname"],
    decode.string,
  )

  decode.success(RequestInfo(media_type:, tmdb_id:, requested_by:))
}

fn media_type_decoder() {
  use value <- decode.then(decode.string)
  case value {
    "movie" -> decode.success(Movie)
    "tv" -> decode.success(Tv)

    _ -> decode.failure(Movie, "Failed to decode MediaType")
  }
}
