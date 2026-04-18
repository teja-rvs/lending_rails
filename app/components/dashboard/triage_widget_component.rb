module Dashboard
  class TriageWidgetComponent < ApplicationComponent
    TONE_BORDER_CLASSES = {
      danger: "border-l-rose-500",
      warning: "border-l-amber-500",
      success: "border-l-emerald-500",
      neutral: "border-l-slate-300"
    }.freeze

    TONE_TEXT_CLASSES = {
      danger: "text-rose-600",
      warning: "text-amber-600",
      success: "text-emerald-600",
      neutral: "text-slate-900"
    }.freeze

    def initialize(title:, count:, href:, label:, tone: :neutral)
      @title = title
      @count = count
      @href = href
      @label = label
      @tone = tone.to_sym
    end

    attr_reader :title, :count, :href, :label, :tone

    def border_class
      TONE_BORDER_CLASSES.fetch(tone, TONE_BORDER_CLASSES[:neutral])
    end

    def count_class
      TONE_TEXT_CLASSES.fetch(tone, TONE_TEXT_CLASSES[:neutral])
    end
  end
end
