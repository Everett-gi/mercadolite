# Quem pode fazer o quê com pedidos: o comprador vê e paga SÓ os próprios pedidos (anti-IDOR).
class OrderPolicy < ApplicationPolicy
  def index? = user.present?
  def show? = owner?
  def create? = owner?

  class Scope < ApplicationPolicy::Scope
    # @return [ActiveRecord::Relation<Order>] só os pedidos do usuário (nenhum, sem login)
    def resolve
      user ? scope.where(user:) : scope.none
    end
  end

  private

  def owner?
    user.present? && record.user_id == user.id
  end
end
