class Delivery < ActiveRecord::Base
  PER_YEAR = 40

  default_scope { order(:date) }

  scope :coming, -> { where('date >= ?', Date.today)}
  scope :between,
    ->(range) { where('date >= ? AND date <= ?', range.first, range.last) }

  def self.create_all(first_date)
    date = first_date
    PER_YEAR.times do
      create(date: date)
      date = next_date(date)
    end
  end

  private

  def self.next_date(date)
    if date >= Date.new(date.year, 5, 15) && date <= Date.new(date.year, 12, 15)
      date + 1.week
    else
      date + 2.weeks
    end
  end
end
