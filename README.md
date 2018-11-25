# everyelixirvideo.page

## Development tasks

### Prerequisites

* obtain a valid YouTube API access token.

### Updating view counts

In order to update video view counts for videos contained in a given YAML file, run:

```fish
env YOUTUBE_API_KEY=AIzaSyDG1Q7sLXyHOjIzSXHTBaUEDYTvtqUHnt0 bin/update_duration _data/elixirconf_us_2018.yaml
```

In order to update video view counts for all videos, run:

```fish
env YOUTUBE_API_KEY=AIzaSyDG1Q7sLXyHOjIzSXHTBaUEDYTvtqUHnt0 bin/update_duration
```
