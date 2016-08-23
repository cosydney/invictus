class Invoice < ActiveRecord::Base
  # Newsfeed gem
  include PublicActivity::Model
  # ----
  belongs_to :freelancer
  belongs_to :client
  has_many :transitions, class_name: "InvoiceTransition", autosave: false
  has_many :descriptions, dependent: :destroy

  before_destroy :destroy_activity
  after_create :create_activity
  after_update :update_activity

  accepts_nested_attributes_for :client
  accepts_nested_attributes_for :descriptions, reject_if: :all_blank

  validates :invoice_nr, presence: true

  # This method is called now from the invoice controller with an if statement,
  # id the client is existing, we send it the invoice, else we sent him the invitable
  # after_create :send_invoice_by_email

  def self.freelance_invoices(freelance)
    @invoices = freelance.freelancer.invoices
  end

  # This is done to give some state to each invoice and tell the freelancer what is it.
  def state_machine
    @state_machine ||= InvoiceStateMachine.new(self, transition_class: InvoiceTransition,
                                                      association_name: :transitions)
  end

  # optionally delegating some methods
  delegate :can_transition_to?, :transition_to!, :transition_to, :current_state,
          to: :state_machine
  # After the invoice gets created do:


  def send_invoice_by_email!(text)
    # Calling method in user_mailer.rb, delivers later so user doesn't have to wait
    UserMailer.send_invoice_client(self.id, text).deliver_later
    self.email_sent_at = Time.now
    log_activity :sent
    save
  end

  def destroy_activity
    log_activity :destroy
  end

  def update_activity
    log_activity :update
  end

  def create_activity
    log_activity :create
  end

  protected

  def log_activity(type)
    create_activity(
      key: "invoice.#{type}",
      owner: Proc.new{ |controller, model| controller.current_user },
      parameters:{ client_name: client.first_name, client_last_name: client.last_name, company: client.company }
    )
  end
end
