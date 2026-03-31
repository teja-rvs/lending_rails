SimpleCov.enable_coverage :branch

SimpleCov.start "rails" do
  minimum_coverage line: 80, branch: 50

  add_filter "/bin/"
  add_filter "/config/"
  add_filter "/db/"
  add_filter "/spec/"

  add_group "Controllers", "app/controllers"
  add_group "Models", "app/models"
  add_group "Services", "app/services"
  add_group "Policies", "app/policies"
  add_group "Queries", "app/queries"
  add_group "Components", "app/components"
end
