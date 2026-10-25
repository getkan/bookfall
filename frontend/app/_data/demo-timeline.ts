export type DemoBook = {
  id: string;
  title: string;
  author: string;
  reader: string;
  startedAt: string;
  finishedAt: string | null;
  coverTitle: string;
  coverStyle: string;
};

export const demoBooks: DemoBook[] = [
  {
    id: "blue-hour",
    title: "The House in the Cerulean Sea",
    author: "TJ Klune",
    reader: "Maya",
    startedAt: "2026-09-03",
    finishedAt: "2026-09-18",
    coverTitle: "THE HOUSE\nIN THE\nCERULEAN SEA",
    coverStyle: "cover-blue",
  },
  {
    id: "quiet-world",
    title: "A Psalm for the Wild-Built",
    author: "Becky Chambers",
    reader: "Nora",
    startedAt: "2026-09-12",
    finishedAt: null,
    coverTitle: "A PSALM\nFOR THE\nWILD-BUILT",
    coverStyle: "cover-green",
  },
  {
    id: "sea-of-tranquility",
    title: "Sea of Tranquility",
    author: "Emily St. John Mandel",
    reader: "Liam",
    startedAt: "2026-09-08",
    finishedAt: "2026-09-21",
    coverTitle: "SEA OF\nTRANQUILITY",
    coverStyle: "cover-orange",
  },
  {
    id: "midnight-library",
    title: "The Midnight Library",
    author: "Matt Haig",
    reader: "Maya",
    startedAt: "2026-09-18",
    finishedAt: "2026-10-02",
    coverTitle: "THE\nMIDNIGHT\nLIBRARY",
    coverStyle: "cover-violet",
  },
  {
    id: "piranesi",
    title: "Piranesi",
    author: "Susanna Clarke",
    reader: "Ellis",
    startedAt: "2026-10-01",
    finishedAt: "2026-10-11",
    coverTitle: "PIRANESI",
    coverStyle: "cover-lilac",
  },
  {
    id: "creative-act",
    title: "The Creative Act: A Way of Being",
    author: "Rick Rubin",
    reader: "Liam",
    startedAt: "2026-10-11",
    finishedAt: null,
    coverTitle: "THE\nCREATIVE\nACT",
    coverStyle: "cover-cream",
  },
  {
    id: "irregular-witches",
    title: "The Very Secret Society of Irregular Witches",
    author: "Sangu Mandanna",
    reader: "Nora",
    startedAt: "2026-10-19",
    finishedAt: null,
    coverTitle: "THE VERY\nSECRET SOCIETY",
    coverStyle: "cover-rose",
  },
];
