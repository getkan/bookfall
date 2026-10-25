namespace :book_events do
  desc "Synchronize changed Books into BookEvents using the last successful checkpoint"
  task sync: :environment do
    BookEventSync.call
  end
end
