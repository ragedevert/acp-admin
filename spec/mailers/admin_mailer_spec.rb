require 'rails_helper'

describe AdminMailer do
  specify '#invitation_email' do
    admin = Admin.new(
      name: 'John',
      language: I18n.locale,
      email: 'admin@acp-admin.ch')
    mail = AdminMailer.with(
      admin: admin,
      action_url: 'https://admin.ragedevert.ch'
    ).invitation_email

    expect(mail.subject).to eq("Invitation à l'admin de Rage de Vert")
    expect(mail.to).to eq(['admin@acp-admin.ch'])
    expect(mail.body).to include('Salut John,')
    expect(mail.body).to include('admin@acp-admin.ch')
    expect(mail.body).to include("Accèder à l'admin de Rage de Vert")
    expect(mail.body).to include('https://admin.ragedevert.ch')
    expect(mail.from).to eq(['info@ragedevert.ch'])
  end

  specify '#invoice_overpaid_email' do
    admin = Admin.new(
      id: 1,
      name: 'John',
      language: I18n.locale,
      email: 'admin@acp-admin.ch')
    member =  Member.new(
      id: 2,
      name: 'Martha')
    invoice = Invoice.new(id: 42)
    mail = AdminMailer.with(
      admin: admin,
      member: member,
      invoice: invoice
    ).invoice_overpaid_email

    expect(mail.subject).to eq('Facture #42 payée en trop')
    expect(mail.to).to eq(['admin@acp-admin.ch'])
    expect(mail.body).to include('Salut John,')
    expect(mail.body).to include('Facture #42')
    expect(mail.body).to include('Martha')
    expect(mail.body).to include('Accèder à la page du membre')
    expect(mail.body).to include('https://admin.ragedevert.ch/members/2')
    expect(mail.body).to include('https://admin.ragedevert.ch/admins/1/edit#admin_notifications_input')
    expect(mail.from).to eq(['info@ragedevert.ch'])
  end

  specify '#new_absence_email' do
    admin = Admin.new(
      id: 1,
      name: 'John',
      language: I18n.locale,
      email: 'admin@acp-admin.ch')
    member =  Member.new(name: 'Martha')
    absence = Absence.new(
      id: 1,
      started_on: Date.new(2020, 11, 10),
      ended_on: Date.new(2020, 11, 20))
    mail = AdminMailer.with(
      admin: admin,
      member: member,
      absence: absence
    ).new_absence_email

    expect(mail.subject).to eq('Nouvelle absence')
    expect(mail.to).to eq(['admin@acp-admin.ch'])
    expect(mail.body).to include('Salut John,')
    expect(mail.body).to include('Martha')
    expect(mail.body).to include('10 novembre 2020 au 20 novembre 2020')
    expect(mail.body).to include("Accèder à la page de l'absence")
    expect(mail.body).to include('https://admin.ragedevert.ch/absences/1')
    expect(mail.body).to include('https://admin.ragedevert.ch/admins/1/edit#admin_notifications_input')
    expect(mail.from).to eq(['info@ragedevert.ch'])
  end

  specify '#new_inscription_email' do
    admin = Admin.new(
      id: 1,
      name: 'John',
      language: I18n.locale,
      email: 'admin@acp-admin.ch')
    member =  Member.new(
      id: 2,
      name: 'Martha')
    mail = AdminMailer.with(
      admin: admin,
      member: member
    ).new_inscription_email

    expect(mail.subject).to eq('Nouvelle inscription')
    expect(mail.to).to eq(['admin@acp-admin.ch'])
    expect(mail.body).to include('Salut John,')
    expect(mail.body).to include('Martha')
    expect(mail.body).to include("cèder à la page du membr")
    expect(mail.body).to include('https://admin.ragedevert.ch/members/2')
    expect(mail.body).to include('https://admin.ragedevert.ch/admins/1/edit#admin_notifications_input')
    expect(mail.from).to eq(['info@ragedevert.ch'])
  end
end
