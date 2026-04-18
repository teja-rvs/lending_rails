module Dashboard
  class SummaryWidgetComponent < ApplicationComponent
    def initialize(title:, value:, href: nil, label: nil)
      @title = title
      @value = value
      @href = href
      @label = label
    end

    attr_reader :title, :value, :href, :label

    def link?
      href.present? && label.present?
    end
  end
end
