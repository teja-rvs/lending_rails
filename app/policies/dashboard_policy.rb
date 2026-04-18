# frozen_string_literal: true

class DashboardPolicy < ApplicationPolicy
  def show?
    true
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
