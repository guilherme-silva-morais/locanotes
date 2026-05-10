class NotePolicy < ApplicationPolicy
  # The Scope is what `policy_scope(Note)` returns in the controller — used
  # for `index` so users only ever see their own notes (no cross-user leak).
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user_id: user.id)
    end
  end

  def index?
    user.present?
  end

  def create?
    user.present?
  end

  def show?
    owner?
  end

  def update?
    owner?
  end

  def destroy?
    owner?
  end

  private
    def owner?
      record.user_id == user.id
    end
end
