module DeletionProtection
  extend ActiveSupport::Concern

  included do
    before_destroy :prevent_deletion
  end

  private

  def prevent_deletion
    raise ActiveRecord::ReadOnlyRecord, "#{self.class.name} records cannot be deleted"
  end
end
