require 'rails_helper'

describe Notifier do
  specify '.send_membership_renewal_reminder_emails' do
    Current.acp.update!(open_renewal_reminder_sent_after_in_days: 10)
    MailTemplate.create! title: :membership_renewal_reminder, active: true
    next_fy = Current.acp.fiscal_year_for(Date.today.year + 1)
    Delivery.create_all(1, next_fy.beginning_of_year)
    member = create(:member, emails: 'john@doe.com')

    create(:membership, renewal_opened_at: nil)
    create(:membership, renewal_opened_at: 10.days.ago).update_column(:renewed_at, 10.days.ago)
    create(:membership, renewal_opened_at: 10.days.ago, member: member)
    create(:membership, renewal_opened_at: 10.days.ago, renewal_reminder_sent_at: 1.minute.ago)
    create(:membership, :last_year, renewal_opened_at: 10.days.ago)

    expect { Notifier.send_membership_renewal_reminder_emails }
      .to change { MembershipMailer.deliveries.size }.by(1)

    mail = MembershipMailer.deliveries.last
    expect(mail.subject).to eq 'Renouvellement de votre abonnement (Rappel)'
    expect(mail.to).to eq ['john@doe.com']
  end

  specify '.send_membership_last_trial_basket_emails' do
    Current.acp.update!(trial_basket_count: 2)
    travel_to '2021-05-03' do
      MailTemplate.create! title: :membership_last_trial_basket, active: true
      create(:delivery, date: '2021-05-01')
      create(:delivery, date: '2021-05-02')
      create(:delivery, date: '2021-05-03')
      create(:delivery, date: '2021-05-04')
      member = create(:member, emails: 'john@doe.com')

      create(:membership, started_on: '2021-05-01')
      create(:membership, started_on: '2021-05-03')
      create(:membership, started_on: '2021-05-02', member: member)
      create(:membership, started_on: '2021-05-02', ended_on: '2021-05-03')
      create(:membership, started_on: '2021-05-02', last_trial_basket_sent_at: 1.minute.ago)

      expect { Notifier.send_membership_last_trial_basket_emails }
        .to change { MembershipMailer.deliveries.size }.by(1)

      mail = MembershipMailer.deliveries.last
      expect(mail.subject).to eq "Dernier panier à l'essai!"
      expect(mail.to).to eq ['john@doe.com']
    end
  end
end
