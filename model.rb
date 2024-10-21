# chamado de referencia:I2403-026015
require 'csv'
# Consts
@headers = %w[
              person_id
              acronym
              country
              plan
              origin
              charging_period_annual?
              main_purchase_id
              created_at
              confirmed_at
              cancelled_at
              expired_at
              cancelling_reason_other
              signed_at
              upgraded_at
              is_main_purchase?
              promotion_id
              purchase_membership_price
              map_membership_amount_paid
              map_membership_state
              map_membership_due_at
]
@result_path = "/tmp/levantamento_I2410-068925-#{Date.current.strftime('%Y-%m-%d')}.csv"
@emails_to_send_report = ['jose.alves@bioritmo.com']
def write_case(purchase)
  row = [
        get_hyperlink_person_id!(purchase),
        purchase.location.acronym,
        purchase.location.country.name,
        purchase.plan.name,
        purchase.origin,
        purchase.charging_period_annual?,
        purchase.id,
        purchase.created_at,
        purchase.confirmed_at,
        purchase.cancelled,
        purchase.expired_at,
        purchase.cancelling_reason_other,
        purchase.signed_at,
        (purchase.plan_changes.where(kind: :upgrade).last.created_at rescue nil),
        purchase.is_main_purchase?,
        (!purchase.promotion_id.nil? ? get_hyperlink_promotion_id!(purchase.promotion) : nil),
        purchase.membership_price.to_s,
        (purchase.membership_payments.not_paid.map{|p| p.base_amount_paid.to_f}.join(' - ').to_s rescue nil),
        (purchase.membership_payments.not_paid.map{|p| p.state}.join(' - ').to_s rescue nil),
        (purchase.membership_payments.not_paid.map{|p| p.due_at}.join(' - ').to_s rescue nil)
  ]
  write_in_csv(row)
end
def send_email
  Mailer.send_files(
    @result_path,
    @result_path,
    [@result_path],
    @emails_to_send_report
  ).deliver_now; nil
end
def is_main_purchase?
  nil if self.nil?
  (id == person.main_purchase.id)
end
def write_in_csv(row)
  CSV.open(@result_path, 'a', col_sep: ';') { |csv| csv << row }
end
def get_hyperlink_person_id!(purchase)
  %Q{=HYPERLINK("https://app.smartfit.com.br/admin/people/#{purchase.person.single_access_token}";"#{purchase.person_id}")}
end
def get_hyperlink_promotion_id!(promotion)
  %Q{=HYPERLINK("https://app.smartfit.com.br/admin/campaigns/#{promotion.id}/edit";"#{promotion.id}")}
end
# Execution
CSV.open(@result_path, 'w', col_sep: ';') do |csv|
  csv << @headers
end
purchases = Promotion.find(19629).purchases.joins(:membership_payments).where(payments: {state: "opened",amount_paid: 0,  payable_type: "Membership"})
total_purchases = purchases.count
purchases.each_with_index do |purchase, index|
printf "\r| Progresso #{(((index + 1).to_f / total_purchases.to_f) * 100).round(2)}%% --> Faltam --> #{total_purchases.to_i-index.to_i} --> Total --> #{total_purchases.to_i} | Person --> #{purchase.person.id}"
  write_case(purchase)
end;nil
send_email
