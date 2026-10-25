class StagingSeeds
  BOOKS_PATH = Rails.root.join("db/seeds/books.yml")
  NATURAL_KEY = %w[title author started_at].freeze
  ATTRIBUTES = %w[user_id title author started_at finished_at rating review].freeze

  # Creates missing Books only. Existing matches are left untouched, and
  # BookEvents are produced later by book_events:sync.
  def self.load!(path: BOOKS_PATH)
    records = YAML.safe_load(ERB.new(File.read(path)).result, permitted_classes: [], aliases: false)
    raise ArgumentError, "Seed file must contain a mapping of books" unless records.is_a?(Hash)

    Book.transaction do
      records.each_value do |attributes|
        attributes = attributes.slice(*ATTRIBUTES)
        book = Book.new(attributes)
        book.validate!

        Book.find_or_create_by!(NATURAL_KEY.index_with { |key| book.public_send(key) }) do |created|
          created.assign_attributes(attributes)
        end
      end
    end
  end
end
