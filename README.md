# homelab-json-api

First off, big thanks to [Svilen Markov](https://github.com/svilenmarkov) for creating [Glance](https://github.com/glanceapp/glance) ❤

This project exists to consolidate sequential requests into a single endpoint for convenience in my personal Glance dashboard.
If you like the consolidations I've done, feel free to use this! If not, or if you need more, fork this and go ham!

> [!NOTE]
> I'm deciding to avoid using the `extension` component for now since it's still actively in development and I'm planning on only changing this when I want to consolidate more requests

## Environment variables

> [!WARNING]
> This assumes that you're using this project as is. If you add your own endpoints, make sure you account for any extra required API keys

1. `ACCESS_TOKEN` This will be the token to use when calling this API. If your services are exposed and/or not behind a reverse proxy, make sure it's something secure
2. `JELLYSEERR_SERVER_URL` The URL where your Jellyseer app is located
3. `JELLYSEERR_API_KEY` The API key to make requests to your Jellyseerr app

## Coming soon
I'm considering adding my custom widgets to this repo since they don't adhere to the contribution guidelines for official community widgets, and I personally don't have the motivation to convert all the component-specific classes to just using the css helper classes
