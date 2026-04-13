module Shared
  class StatusBadgeComponent < ApplicationComponent
    TONE_CLASSES = {
      danger: "border-rose-200 bg-rose-50 text-rose-700",
      neutral: "border-slate-200 bg-slate-100 text-slate-700",
      success: "border-emerald-200 bg-emerald-50 text-emerald-700",
      warning: "border-amber-200 bg-amber-50 text-amber-700"
    }.freeze

    def initialize(label:, tone: :neutral)
      @label = label
      @tone = tone.to_sym
    end

    attr_reader :label, :tone

    def classes
      [
        "inline-flex items-center rounded-full border px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em]",
        TONE_CLASSES.fetch(tone, TONE_CLASSES[:neutral])
      ].join(" ")
    end
  end
end
