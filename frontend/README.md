# Bookfall frontend

The frontend is a responsive, timeline-first prototype built with Next.js,
React, and TypeScript. The landing page currently uses local demo records from
[`app/_data/demo-timeline.ts`](./app/_data/demo-timeline.ts); it does not yet
connect to the Rails API or provide authentication and admin flows.

## Local development

Use Node.js 20.9 or newer. From this directory:

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Validation

```bash
npm run lint
npm run build
```
