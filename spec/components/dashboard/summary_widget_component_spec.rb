require "rails_helper"

RSpec.describe Dashboard::SummaryWidgetComponent, type: :component do
  it "renders title and value" do
    component = described_class.new(title: "Closed loans", value: "12")

    render_inline(component)

    expect(page).to have_text("Closed loans")
    expect(page).to have_text("12")
  end

  it "renders drill-in link when href provided" do
    component = described_class.new(
      title: "Closed loans",
      value: "12",
      href: "/loans?status=closed",
      label: "View all"
    )

    render_inline(component)

    expect(page).to have_link("View all", href: "/loans?status=closed")
  end

  it "omits link when href is nil" do
    component = described_class.new(title: "Total disbursed", value: "₹1,25,000.00")

    render_inline(component)

    expect(page).to have_text("Total disbursed")
    expect(page).to have_text("₹1,25,000.00")
    expect(page).not_to have_link
  end
end
