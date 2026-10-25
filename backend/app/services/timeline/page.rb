module Timeline
  class Page
    def self.call(cursor: nil)
      raise FeatureNotImplemented, "Revision-pinned timeline pagination is reserved for Stage 3"
    end
  end
end
