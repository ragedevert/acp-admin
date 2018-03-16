ActiveAdmin.register Member do
  menu priority: 2

  scope :all
  scope :pending
  scope :waiting
  scope :trial, if: ->(_) { Current.acp.trial_basket_count.positive? }
  scope :active, default: true
  scope :support
  scope :inactive

  index do
    if params[:scope] == 'waiting'
      @waiting_started_ats ||= Member.waiting.order(:waiting_started_at).pluck(:waiting_started_at)
      column '#', ->(member) {
        @waiting_started_ats.index(member.waiting_started_at) + 1
      }, sortable: :waiting_started_at
    end
    column :name, ->(member) { auto_link member }
    column :city, ->(member) { member.city? ? "#{member.city} (#{member.zip})" : nil }
    column :state, ->(member) { status_tag(member.state) }
    if params[:scope] == 'trial'
      column 'Paniers', ->(member) { member.delivered_baskets.size }
    end
    actions
  end

  show do |member|
    columns do
      column do
        panel link_to('Abonnements', memberships_path(q: { member_id_eq: member.id }, scope: :all)) do
          memberships = member.memberships.includes(:delivered_baskets).order(:started_on)
          if memberships.none?
            em 'Aucun abonnement'
          else
            table_for(memberships, class: 'table-memberships') do
              column(:period) { |m| auto_link m, membership_short_period(m) }
              column(halfdays_human_name) { |m|
                auto_link m, "#{m.validated_halfday_works} / #{m.halfday_works}"
              }
              column(:baskets) { |m|
                auto_link m, "#{m.delivered_baskets.size} / #{m.baskets_count}"
              }
            end
          end
        end

        halfday_participations = member.halfday_participations.includes(:halfday).order('halfdays.date, halfdays.start_time')
        count = halfday_participations.count
        panel link_to("#{halfdays_human_name} (#{count})", halfday_participations_path(q: { member_id_eq: member.id }, scope: :all)) do
          if halfday_participations.none?
            em "Aucune #{halfdays_human_name.downcase}"
          else
            table_for(halfday_participations.offset([count - 5, 0].max), class: 'table-halfday_participations') do
              column('Description') { |hp|
                link_to hp.halfday.name, halfday_participations_path(q: { halfday_id_eq: hp.halfday_id }, scope: :all)
              }
              column('Part. #', &:participants_count)
              column(:state) { |hp| status_tag(hp.state) }
            end
          end
        end

        panel link_to('Factures', invoices_path(q: { member_id_eq: member.id }, scope: :all)) do
          invoices = member.invoices.order(:date)
          if invoices.none?
            em 'Aucune facture'
          else
            table_for(invoices, class: 'table-invoices') do
              column(:id) { |i| auto_link i, i.id }
              column(:date) { |i| l(i.date, format: :number) }
              column(:amount) { |i| number_to_currency(i.amount) }
              column(:balance) { |i| number_to_currency(i.balance) }
              column('Rap.', &:overdue_notices_count)
              column(class: 'col-actions') { |i|
                link_to 'PDF', rails_blob_path(i.pdf_file, disposition: 'attachment'), class: 'pdf_link'
              }
              column(:status) { |i| status_tag i.state }
            end
          end
        end

        panel link_to('Paiements', payments_path(q: { member_id_eq: member.id }, scope: :all)) do
          payments = member.payments.includes(:invoice).order(:date)
          if payments.none?
            em 'Aucun paiement'
          else
            table_for(payments, class: 'table-payments') do
              column(:date) { |p| l(p.date, format: :number) }
              column(:invoice_id) { |p| p.invoice_id ? auto_link(p.invoice, p.invoice_id) : '–' }
              column(:amount) { |p| number_to_currency(p.amount) }
              column(:type) { |p| status_tag p.type }
            end
          end
        end
      end

      column do
        attributes_table title: 'Détails' do
          row :id
          row :name
          row(:status) { status_tag member.state }
          row(:created_at) { l member.created_at }
          row(:validated_at) { member.validated_at ? l(member.validated_at) : nil }
          row :validator
        end
        if member.pending? || member.waiting?
          attributes_table title: 'Abonnement (en attente)' do
            row :waiting_started_at
            row :waiting_basket_size
            if BasketComplement.any?
              row(:waiting_basket_complement_ids) {
                member.waiting_basket_complements.map(&:name).to_sentence
              }
            end
            row :waiting_distribution
          end
        end
        attributes_table title: 'Adresse' do
          span member.display_address
        end
        unless member.same_delivery_address?
          attributes_table title: 'Adresse (Livraison)' do
            span member.display_delivery_address
          end
        end
        attributes_table title: 'Contact' do
          row(:emails) { display_emails(member.emails_array) }
          row(:phones) { display_phones(member.phones_array) }
          if feature?('gribouille')
            row(:gribouille) { status_tag(member.gribouille? ? :yes : :no) }
          end
        end
        attributes_table title: 'Facturation' do
          row(:billing_year_division) { t("billing.year_division._#{member.billing_year_division}") }
          row(:salary_basket) { member.salary_basket? ? 'oui' : 'non' }
          row(:support_member) { member.support_member ? 'oui' : 'non' }
          row(:support_price) { number_to_currency member.support_price }
          row('Montant facturé') { number_to_currency member.invoices.not_canceled.sum(:amount) }
          row('Paiements versés') { number_to_currency member.payments.sum(:amount) }
          row('Différence') {
            number_to_currency(member.invoices.not_canceled.sum(:amount) - member.payments.sum(:amount))
          }
        end
        attributes_table title: 'Info et Notes' do
          row :profession
          row :come_from
          row(:food_note) { simple_format member.food_note }
          row(:note) { simple_format member.note }
        end

        active_admin_comments
      end
    end
  end

  filter :with_name, as: :string
  filter :with_address, as: :string
  filter :with_phone, as: :string
  filter :with_email, as: :string
  filter :city, as: :select, collection: -> {
    Member.pluck(:city).uniq.map(&:presence).compact.sort
  }
  filter :billing_year_division,
    as: :select,
    collection: -> { Current.acp.billing_year_divisions.map { |i| [I18n.t("billing.year_division._#{i}"), i] } }

  form do |f|
    f.inputs 'Details' do
      f.input :name
    end
    if member.pending? || member.waiting?
      f.inputs 'Abonnement (en attente)' do
        f.input :waiting_basket_size, label: 'Panier'
        if BasketComplement.any?
          f.input :waiting_basket_complement_ids,
            as: :check_boxes,
            collection: BasketComplement.all
        end
        f.input :waiting_distribution, label: 'Distribution'
      end
    end
    f.inputs 'Adresse' do
      f.input :address
      f.input :city
      f.input :zip
    end
    f.inputs 'Adresse (Livraison)' do
      f.input :delivery_address
      f.input :delivery_city
      f.input :delivery_zip
    end
    f.inputs 'Contact' do
      f.input :emails
      f.input :phones
      if feature?('gribouille')
        f.input :gribouille, as: :select,
          collection: [['Oui', true], ['Non', false]]
      end
    end
    f.inputs 'Facturation' do
      f.input :billing_year_division,
        as: :select,
        collection: Current.acp.billing_year_divisions.map { |i| [I18n.t("billing.year_division._#{i}"), i] },
        include_blank: false
      if member.inactive? && !member.future_membership
        f.input :support_member, hint: 'Paye la cotisation annuelle même si aucun abonnement'
      end
      f.input :support_price
      f.input :salary_basket, label: 'Panier(s) salaire / Abonnement(s) gratuit(s)'
    end
    f.inputs 'Info et Notes' do
      f.input :profession
      f.input :come_from
      f.input :food_note, input_html: { rows: 3 }
      f.input :note, input_html: { rows: 3 }
    end
    f.actions
  end

  permit_params \
    :name, :address, :city, :zip, :emails, :phones, :gribouille,
    :delivery_address, :delivery_city, :delivery_zip,
    :support_member, :support_price, :salary_basket, :billing_year_division,
    :waiting, :waiting_basket_size_id, :waiting_distribution_id,
    :profession, :come_from, :food_note, :note,
    waiting_basket_complement_ids: []

  action_item :create_invoice, only: :show, if: -> { authorized?(:create_invoice, resource) } do
    link_to 'Facturer', create_invoice_member_path(resource), method: :post
  end
  action_item :validate, only: :show, if: -> { authorized?(:validate, resource) } do
    link_to 'Valider', validate_member_path(resource), method: :post
  end
  action_item :remove_from_waiting_list, only: :show, if: -> { authorized?(:remove_from_waiting_list, resource) } do
    link_to "Retirer de la liste d'attente", remove_from_waiting_list_member_path(resource), method: :post
  end
  action_item :put_back_to_waiting_list, only: :show, if: -> { authorized?(:put_back_to_waiting_list, resource) } do
    link_to "Remettre en liste d'attente", put_back_to_waiting_list_member_path(resource), method: :post
  end
  action_item :create_membership, only: :show, if: -> { resource.waiting? && authorized?(:create, Membership) } do
    next_delivery = Delivery.next
    link_to 'Créer abonnement',
      new_membership_path(
        member_id: resource.id,
        basket_size_id: resource.waiting_basket_size_id,
        distribution_id: resource.waiting_distribution_id,
        subscribed_basket_complement_ids: resource.waiting_basket_complement_ids,
        started_on: [Date.current, next_delivery.fy_range.min, next_delivery.date.beginning_of_week].max)
  end

  collection_action :gribouille_emails, method: :get do
    render plain: Member.gribouille_emails.to_csv
  end

  member_action :validate, method: :post do
    resource.validate!(current_admin)
    redirect_to member_path(resource)
  end

  member_action :remove_from_waiting_list, method: :post do
    resource.remove_from_waiting_list!
    redirect_to member_path(resource)
  end

  member_action :put_back_to_waiting_list, method: :post do
    resource.put_back_to_waiting_list!
    redirect_to member_path(resource)
  end

  member_action :create_invoice, method: :post do
    RecurringBilling.invoice(resource)
    redirect_to invoices_path(q: { member_id_eq: resource.id }, scope: :all, order: :date_asc)
  end

  before_build do |member|
    member.support_price ||= Current.acp.support_price
  end

  controller do
    def apply_sorting(chain)
      params[:order] ||= 'waiting_started_at_asc' if params[:scope] == 'waiting'
      super
    end

    def scoped_collection
      if params[:scope] == 'trial'
        Member.includes(:delivered_baskets)
      else
        Member.all
      end
    end

    def find_resource
      Member.find_by!(token: params[:id])
    end

    def create_resource(object)
      run_create_callbacks object do
        object.validated_at = Time.current
        object.validator = current_admin
        save_resource(object)
      end
    end
  end

  config.per_page = 50
  config.sort_order = 'name_asc'
end
