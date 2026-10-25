module Timeline
  class Refresh
    def self.call
      raise FeatureNotImplemented, "Forced timeline cache refresh is reserved for Stage 3"
    end
  end
end
