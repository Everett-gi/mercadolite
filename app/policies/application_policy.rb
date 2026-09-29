# Base das regras de autorização (Pundit). Cada modelo que precisa de regra ganha uma
# "policy": uma classe com um método por ação ("show?", "create?"...) que responde true/false.
#
# O padrão aqui é NEGAR: uma ação que a policy não liberar explicitamente fica proibida.
class ApplicationPolicy
  attr_reader :user, :record

  # @param user [User, nil] quem está logado (o current_user do Devise)
  # @param record [Object] o que se quer acessar (um pedido, por exemplo)
  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = false
  def show? = false
  def create? = false
  def new? = create?
  def update? = false
  def edit? = update?
  def destroy? = false

  # O escopo: DE TODOS os registros, quais este usuário pode enxergar. Listagens e buscas
  # por id partem daqui (policy_scope), e o resto nem é consultado.
  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "defina #resolve em #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end
