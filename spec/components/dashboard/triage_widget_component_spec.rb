require "rails_helper"

RSpec.describe Dashboard::TriageWidgetComponent, type: :component do
  it "renders title, count, and drill-in link" do
    component = described_class.new(
      title: "Overdue payments",
      count: 5,
      tone: :danger,
      href: "/payments?view=overdue",
      label: "View all"
    )

    render_inline(component)

    expect(page).to have_text("Overdue payments")
    expect(page).to have_text("5")
    expect(page).to have_link("View all", href: "/payments?view=overdue")
  end

  it "applies danger tone classes for :danger" do
    component = described_class.new(
      title: "Overdue payments",
      count: 3,
      tone: :danger,
      href: "/payments?view=overdue",
      label: "View all"
    )

    render_inline(component)

    expect(page).to have_css("article.border-l-rose-500")
    expect(page).to have_css("p.text-rose-600", text: "3")
  end

  it "applies warning tone classes for :warning" do
    component = described_class.new(
      title: "Upcoming payments",
      count: 7,
      tone: :warning,
      href: "/payments?view=upcoming",
      label: "View all"
    )

    render_inline(component)

    expect(page).to have_css("article.border-l-amber-500")
    expect(page).to have_css("p.text-amber-600", text: "7")
  end

  it "applies neutral tone classes for :neutral" do
    component = described_class.new(
      title: "Active loans",
      count: 12,
      tone: :neutral,
      href: "/loans?status=active",
      label: "View all"
    )

    render_inline(component)

    expect(page).to have_css("article.border-l-slate-300")
    expect(page).to have_css("p.text-slate-900", text: "12")
  end

  it "renders zero count without error" do
    component = described_class.new(
      title: "Overdue payments",
      count: 0,
      tone: :danger,
      href: "/payments?view=overdue",
      label: "View all"
    )

    render_inline(component)

    expect(page).to have_text("0")
    expect(page).to have_link("View all")
  end
end
