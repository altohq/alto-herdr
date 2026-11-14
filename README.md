# alto-herdr

Run [herdr](https://github.com/herdrdev/herdr)'s panes on [Alto](https://github.com/altohq/alto) sessions.

Work in progress: the pieces land one at a time, each with its tests.

- **The reporter** (`bin/alto-herdr-report`): tells herdr what the Alto session in a pane is doing, from Alto's hooks rather than the screen. `alto attach` runs it on each change of state (Alto's `[[attach.report]]`, for panes that have `HERDR_PANE_ID`), and it reports the pane to herdr as an agent: working, blocked with what it asks, idle; released when the session ends, and left as it is when the pane only lets go of it, so herdr's restore shows it again with `alto attach --instead ADDR`.
- **The plugin**, next: sets the reporter up, opens sessions from every host as panes, and makes new panes Alto sessions (`default_shell = "alto-shell"`) if you say so.

## Tests

```sh
sh tests/report.sh
```

## License

Apache-2.0.
