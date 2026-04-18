require "rails_helper"

RSpec.describe Shared::StatusBadgeComponent, type: :component do
  it "renders with :neutral tone classes" do
    render_inline(described_class.new(label: "Open", tone: :neutral))

    expect(page).to have_css("span.border-slate-200.bg-slate-100.text-slate-700", text: "Open")
  end

  it "renders with :success tone classes" do
    render_inline(described_class.new(label: "Approved", tone: :success))

    expect(page).to have_css("span.border-emerald-200.bg-emerald-50.text-emerald-700", text: "Approved")
  end

  it "renders with :warning tone classes" do
    render_inline(described_class.new(label: "Pending", tone: :warning))

    expect(page).to have_css("span.border-amber-200.bg-amber-50.text-amber-700", text: "Pending")
  end

  it "renders with :danger tone classes" do
    render_inline(described_class.new(label: "Rejected", tone: :danger))

    expect(page).to have_css("span.border-rose-200.bg-rose-50.text-rose-700", text: "Rejected")
  end

  it "falls back to neutral classes for an unknown tone" do
    render_inline(described_class.new(label: "Custom", tone: :unknown))

    expect(page).to have_css("span.border-slate-200.bg-slate-100.text-slate-700", text: "Custom")
  end

  it "renders the label text" do
    render_inline(described_class.new(label: "In Progress"))

    expect(page).to have_text("In Progress")
  end
end
