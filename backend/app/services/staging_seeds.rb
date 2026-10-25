class StagingSeeds
  def self.load!
    raise FeatureNotImplemented, "Idempotent staging seed loading is reserved for Stage 3"
  end
end
