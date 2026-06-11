# SeederKit Web

Standalone Vite + TypeScript webpage for the zero-setup `schema.rb -> starter seeds.rb` tool.

This browser utility is separate from the SeederKit Rails engine and does not provide the engine's named scenario workflow.

```bash
npm install
npm run dev
```

The app is fully client-side. It does not send pasted schemas to a server.

Useful commands:

```bash
npm test
npm run build
npm run deploy
```

`npm run deploy` publishes `dist` to the `gh-pages` branch. The custom domain is configured by `public/CNAME`, which Vite copies into the production build as `seederkit.dev`.
