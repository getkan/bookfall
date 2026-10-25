namespace :book_events do
  desc "Synchronize changed Books into BookEvents using the last successful checkpoint"
  task sync: :environment do
    BookEventSync.call
  end

  desc "Publish a fresh timeline cache revision without invalidating pinned revisions"
  task refresh_cache: :environment do
    Timeline::Refresh.call
  end
end
