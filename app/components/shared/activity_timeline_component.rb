module Shared
  class ActivityTimelineComponent < ApplicationComponent
    EVENT_LABELS = {
      "create" => "Created",
      "update" => "Updated",
      "destroy" => "Deleted"
    }.freeze

    def initialize(versions:)
      @versions = versions
    end

    def render?
      @versions.any?
    end

    private

    def entries
      @versions
    end

    def event_label(version)
      EVENT_LABELS.fetch(version.event, version.event.to_s.humanize)
    end

    def actor_display(version)
      return "System" if version.whodunnit.blank?

      actor_lookup[version.whodunnit] || "Unknown user"
    end

    def actor_lookup
      @actor_lookup ||= begin
        ids = @versions.filter_map(&:whodunnit).uniq
        User.where(id: ids).pluck(:id, :email_address).to_h { |id, email| [ id.to_s, email ] }
      end
    end

    def timestamp_display(version)
      version.created_at.to_fs(:long)
    end
  end
end
