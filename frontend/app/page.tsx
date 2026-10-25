import Link from "next/link";
import { demoBooks, type DemoBook } from "./_data/demo-timeline";

type TimelineEvent = {
  id: string;
  book: DemoBook;
  date: string;
  kind: "START" | "FINISHED";
};

function formatDate(date: string, options: Intl.DateTimeFormatOptions) {
  return new Intl.DateTimeFormat("en-US", {
    ...options,
    timeZone: "UTC",
  }).format(new Date(`${date}T00:00:00Z`));
}

function BookGlyph() {
  return (
    <svg
      aria-hidden="true"
      className="brand-glyph"
      viewBox="0 0 36 36"
      fill="none"
    >
      <path
        d="M18 9.25c-3.15-2.25-7.1-2.4-11.75-.5v18c4.65-1.9 8.6-1.75 11.75.5m0-18c3.15-2.25 7.1-2.4 11.75-.5v18c-4.65-1.9-8.6-1.75-11.75.5m0-18v18"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function BookCover({ book }: { book: DemoBook }) {
  return (
    <div
      aria-hidden="true"
      className={`book-cover ${book.coverStyle}`}
    >
      <span className="cover-spark cover-spark-one" />
      <span className="cover-spark cover-spark-two" />
      <span className="cover-art-line" />
      <span className="cover-title">{book.coverTitle}</span>
      <span className="cover-author">{book.author}</span>
      <span className="cover-spine" />
    </div>
  );
}

export default function Home() {
  const completedBooks = demoBooks.filter((book) => book.finishedAt);
  const currentBooks = demoBooks.filter((book) => !book.finishedAt);
  const spotlightBook = currentBooks[0];
  const events = demoBooks
    .flatMap<TimelineEvent>((book) => [
      {
        id: `${book.id}-start`,
        book,
        date: book.startedAt,
        kind: "START",
      },
      ...(book.finishedAt
        ? [
            {
              id: `${book.id}-finished`,
              book,
              date: book.finishedAt,
              kind: "FINISHED" as const,
            },
          ]
        : []),
    ])
    .sort((first, second) => second.date.localeCompare(first.date));
  const eventsByDay = new Map<string, TimelineEvent[]>();

  for (const event of events) {
    const dayEvents = eventsByDay.get(event.date) ?? [];
    dayEvents.push(event);
    eventsByDay.set(event.date, dayEvents);
  }

  return (
    <div className="site-shell">
      <header className="site-header">
        <Link className="brand" href="/" aria-label="Bookfall home">
          <BookGlyph />
          <span>bookfall</span>
          <span className="brand-period">.</span>
        </Link>
        <a className="header-link" href="#timeline">
          THE CLUB TIMELINE
          <span aria-hidden="true">↘</span>
        </a>
      </header>

      <main>
        <section className="hero" aria-labelledby="hero-title">
          <div className="hero-copy">
            <p className="eyebrow">
              <span className="status-dot" />
              A LITTLE MORE BOOK, A LITTLE MORE TOGETHER
            </p>
            <h1 id="hero-title">
              Stories are better
              <br />
              <span>when they&apos;re shared.</span>
            </h1>
            <p className="hero-description">
              One book club, many good reads. Follow what everyone&apos;s
              turning, from the first page to the last.
            </p>
            <a className="button-link" href="#timeline">
              <span>Wander through the reads</span>
              <span aria-hidden="true" className="button-arrow">
                ↓
              </span>
            </a>
          </div>

          <aside className="spotlight-card" aria-label="Currently reading">
            <div className="spotlight-topline">
              <span className="eyebrow">ON SOMEONE&apos;S NIGHTSTAND</span>
              <span className="live-indicator">
                <span className="status-dot" />
                IN PROGRESS
              </span>
            </div>
            <div className="spotlight-content">
              <BookCover book={spotlightBook} />
              <div className="spotlight-details">
                <p className="spotlight-reader">
                  <span className="reader-avatar">
                    {spotlightBook.reader.slice(0, 1)}
                  </span>
                  {spotlightBook.reader}&apos;s pick
                </p>
                <h2>{spotlightBook.title}</h2>
                <p className="muted-copy">by {spotlightBook.author}</p>
                <p className="started-note">
                  Started {formatDate(spotlightBook.startedAt, {
                    month: "short",
                    day: "numeric",
                  })}
                </p>
              </div>
            </div>
            <div className="spotlight-footer">
              <span>A good story travels.</span>
              <BookGlyph />
            </div>
          </aside>
        </section>

        <section
          className="timeline-section"
          id="timeline"
          aria-labelledby="timeline-title"
        >
          <div className="section-heading">
            <div>
              <p className="eyebrow">PAGES TURNED, TOGETHER</p>
              <h2 id="timeline-title">The reading room</h2>
            </div>
            <p className="section-note">
              A little timeline of what&apos;s been keeping us up past bedtime.
            </p>
          </div>

          <div className="timeline-panel">
            <div className="timeline-toolbar">
              <div className="timeline-intro">
                <span className="timeline-icon">
                  <BookGlyph />
                </span>
                <div>
                  <h3>Recent pages</h3>
                  <p>Every beginning has a somewhere-to-go.</p>
                </div>
              </div>
              <div className="timeline-legend" aria-label="Event types">
                <span>
                  <span className="legend-mark legend-start" />
                  STARTED
                </span>
                <span>
                  <span className="legend-mark legend-finished" />
                  FINISHED
                </span>
              </div>
            </div>

            <div className="timeline-stats" aria-label="Club reading summary">
              <span>
                <strong>{demoBooks.length}</strong> books in the mix
              </span>
              <span className="stats-divider" aria-hidden="true" />
              <span>
                <strong>{completedBooks.length}</strong> made it to the last page
              </span>
              <span className="stats-divider" aria-hidden="true" />
              <span>
                <strong>{currentBooks.length}</strong> still unfolding
              </span>
            </div>

            <ol className="timeline-list">
              {Array.from(eventsByDay, ([date, dayEvents]) => (
                <li className="timeline-day" key={date}>
                  <div className="day-date">
                    <time dateTime={date}>
                      <span>{formatDate(date, { month: "short" })}</span>
                      <strong>{formatDate(date, { day: "2-digit" })}</strong>
                    </time>
                  </div>
                  <div className="day-events">
                    {dayEvents.map((event) => (
                      <article
                        className={`event-card event-${event.kind.toLowerCase()}`}
                        key={event.id}
                      >
                        <span className="event-marker" aria-hidden="true">
                          {event.kind === "START" ? "↗" : "✓"}
                        </span>
                        <div className="event-copy">
                          <p className="event-meta">
                            <span className="event-kind">{event.kind}</span>
                            <span className="event-reader">
                              {event.book.reader}
                            </span>
                          </p>
                          <h4>{event.book.title}</h4>
                          <p className="event-author">by {event.book.author}</p>
                        </div>
                      </article>
                    ))}
                  </div>
                </li>
              ))}
            </ol>

            <div className="timeline-endnote">
              <span className="endnote-star" aria-hidden="true">
                ✳
              </span>
              <p>More pages, more perspectives, more reasons to get together.</p>
              <span className="endnote-star" aria-hidden="true">
                ✳
              </span>
            </div>
          </div>
        </section>
      </main>

      <footer className="site-footer">
        <Link className="brand footer-brand" href="/" aria-label="Bookfall home">
          <BookGlyph />
          <span>bookfall</span>
          <span className="brand-period">.</span>
        </Link>
        <p>A cozy corner for stories in progress.</p>
        <span className="footer-date">MADE FOR THE LOVE OF A GOOD BOOK</span>
      </footer>
    </div>
  );
}
