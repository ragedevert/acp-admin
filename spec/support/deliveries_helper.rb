module DeliveriesHelper
  extend self

  def create_deliveries(count, fiscal_year = Current.fiscal_year)
    return if Delivery.during_year(fiscal_year).any?

    date = fiscal_year.beginning_of_year.beginning_of_week + 8.days
    depot_ids = Depot.pluck(:id)
    count.times.each do
      Delivery.create(date: date, depot_ids: depot_ids)
      date += 1.week
    end
  end
end

RSpec.configure do |config|
  config.include(DeliveriesHelper)
end
