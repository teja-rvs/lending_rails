require "rails_helper"

RSpec.describe Shared::ActivityTimelineComponent, type: :component do
  let(:user) { create(:user) }

  def build_version(event:, whodunnit: nil, created_at: Time.current)
    instance_double(
      PaperTrail::Version,
      event: event,
      whodunnit: whodunnit,
      created_at: created_at
    )
  end

  it "renders event labels for each version entry" do
    versions = [
      build_version(event: "create"),
      build_version(event: "update")
    ]

    render_inline(described_class.new(versions: versions))

    expect(page).to have_text("Created")
    expect(page).to have_text("Updated")
  end

  it "renders timestamps for each version entry" do
    timestamp = Time.zone.parse("2026-04-18 12:00:00")
    versions = [ build_version(event: "create", created_at: timestamp) ]

    render_inline(described_class.new(versions: versions))

    expect(page).to have_text(timestamp.to_fs(:long))
  end

  it "resolves whodunnit to user email" do
    versions = [ build_version(event: "update", whodunnit: user.id.to_s) ]

    render_inline(described_class.new(versions: versions))

    expect(page).to have_text(user.email_address)
  end

  it "displays 'System' when whodunnit is nil" do
    versions = [ build_version(event: "create", whodunnit: nil) ]

    render_inline(described_class.new(versions: versions))

    expect(page).to have_text("System")
  end

  it "displays 'Unknown user' when whodunnit references a deleted user" do
    versions = [ build_version(event: "update", whodunnit: SecureRandom.uuid) ]

    render_inline(described_class.new(versions: versions))

    expect(page).to have_text("Unknown user")
  end

  it "does not render when versions collection is empty" do
    render_inline(described_class.new(versions: []))

    expect(page).not_to have_css("section")
    expect(page).not_to have_text("Record history")
  end

  it "renders the Record history heading" do
    versions = [ build_version(event: "create") ]

    render_inline(described_class.new(versions: versions))

    expect(page).to have_css("h2", text: "Record history")
  end

  it "renders entries within an ordered list" do
    versions = [
      build_version(event: "create"),
      build_version(event: "update")
    ]

    render_inline(described_class.new(versions: versions))

    expect(page).to have_css("ol li", count: 2)
  end
end
