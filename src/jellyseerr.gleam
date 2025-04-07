import app/web
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/function
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/result.{map_error, replace_error as error, try}
import gleam/string
import wisp

const api_path = "api/v1"

pub type Error {
  BadURL
  HttpError(httpc.HttpError)
  JSONDecodeError(json.DecodeError)
}

pub type RequestInfo {
  RequestInfo(
    status: Int,
    media_type: String,
    created_at: String,
    requested_by: String,
  )
}

pub type MediaInfo {
  MediaInfo(title: String, backdrop_path: String)
}

pub fn handle(ctx: web.Context) {
  case fetch_data(ctx) {
    Ok(res) -> wisp.ok() |> wisp.json_body(res)

    Error(BadURL) -> {
      wisp.log_error("Could not build request from URL")
      wisp.internal_server_error()
    }
    Error(HttpError(_)) -> {
      wisp.log_error("Request failed")
      wisp.internal_server_error()
    }
    Error(JSONDecodeError(err)) -> {
      wisp.log_error("Unable to decode JSON")
      io.debug(err)
      wisp.internal_server_error()
    }
  }
}

fn fetch_data(ctx: web.Context) {
  use media_request_list <- try(
    request.to(string.join([ctx.jellyseerr_url, api_path, "request"], "/"))
    |> error(BadURL),
  )
  let media_request_list =
    request.set_header(media_request_list, "X-Api-Key", ctx.jellyseerr_api_key)
    |> request.set_query([
      #("take", "10"),
      #("sort", "added"),
      #("sortDirection", "desc"),
    ])

  use media_request_list <- try(
    httpc.send(media_request_list) |> map_error(HttpError),
  )
  use media_request_list <- try(
    json.parse(media_request_list.body, media_requests_decoder())
    |> map_error(JSONDecodeError),
  )

  use media_info_list <- try(
    list.try_map(media_request_list, fn(media_request) {
      let #(id, RequestInfo(media_type: media_type, ..)) = media_request
      let info = get_media_info(id, media_type, ctx)

      // To not burst Jellyseerr API
      process.sleep(100)

      info
    }),
  )

  let combined_data =
    list.fold(over: media_request_list, from: [], with: fn(memo, request) {
      let #(
        id,
        RequestInfo(
          status: status,
          media_type: media_type,
          created_at: requested_at,
          requested_by: requested_by,
        ),
      ) = request
      let assert Ok(media_info) = list.key_find(media_info_list, id)

      let combined =
        json.object([
          #("id", json.int(id)),
          #("title", json.string(media_info.title)),
          #("type", json.string(media_type)),
          #("status", json.int(status)),
          #("requested_at", json.string(requested_at)),
          #("requested_by", json.string(requested_by)),
          #("backdrop_path", json.string(media_info.backdrop_path)),
        ])

      [combined, ..memo]
    })

  json.object([#("results", json.array(combined_data, function.identity))])
  |> json.to_string_tree
  |> Ok()
}

fn media_requests_decoder() -> decode.Decoder(List(#(Int, RequestInfo))) {
  {
    use tmdb_id <- decode.subfield(["media", "tmdbId"], decode.int)
    use status <- decode.field("status", decode.int)
    use created_at <- decode.field("createdAt", decode.string)
    use media_type <- decode.field("type", decode.string)
    use requested_by <- decode.subfield(
      ["requestedBy", "displayName"],
      decode.string,
    )

    decode.success(#(
      tmdb_id,
      RequestInfo(status:, created_at:, media_type:, requested_by:),
    ))
  }
  |> decode.list()
  |> decode.at(["results"], _)
}

fn get_media_info(id: Int, media_type: String, ctx: web.Context) {
  let url =
    string.join(
      [ctx.jellyseerr_url, api_path, media_type, int.to_string(id)],
      "/",
    )

  use media_info <- try(request.to(url) |> error(BadURL))
  let media_info =
    request.set_header(media_info, "X-Api-Key", ctx.jellyseerr_api_key)

  use media_info <- try(httpc.send(media_info) |> map_error(HttpError))
  use media_info <- try(
    json.parse(
      media_info.body,
      decode.one_of(movie_info_decoder(id), [tv_info_decoder(id)]),
    )
    |> map_error(JSONDecodeError),
  )

  Ok(media_info)
}

fn movie_info_decoder(id) -> decode.Decoder(#(Int, MediaInfo)) {
  use title <- decode.field("title", decode.string)
  use backdrop_path <- decode.field("backdropPath", decode.string)

  decode.success(#(id, MediaInfo(title:, backdrop_path:)))
}

fn tv_info_decoder(id) -> decode.Decoder(#(Int, MediaInfo)) {
  use title <- decode.field("name", decode.string)
  use backdrop_path <- decode.field("backdropPath", decode.string)

  decode.success(#(id, MediaInfo(title:, backdrop_path:)))
}
