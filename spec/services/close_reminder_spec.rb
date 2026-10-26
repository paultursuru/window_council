# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe CloseReminder do
  # One window open 10 min ago, aiming at 42 %: close in about 7 min
  let(:now) { Time.now }
  let(:opened) { reading(21.0, 46.0, time: ApplicationHelper.iso(now - 600), windows: 'one') }
  let(:ideal) { { 'VAR_RH_IDEAL' => '42' } }
  let(:id) { 'x-apple-reminder://TEST' }

  def airing(readings = [opened])
    build_report(readings: readings, vars: ideal)
  end

  def calls(script)
    have_received(:osascript).with(script, any_args)
  end

  it 'sets a reminder at closing time when windows open' do
    report = airing
    close_at = report[:airing][:open][:close_at]
    wait = (ApplicationHelper.time_at(close_at) - now).round

    expect(described_class.sync(report, now)).to eq(
      'enabled' => true, 'airing' => "#{opened['at']} one 21.0 46.0", 'id' => id, 'at' => close_at
    )
    expect(described_class).to have_received(:osascript).with(
      CloseReminder::CREATE, REMINDER_LIST, 'Fermer les fenêtres',
      "1 fenêtre depuis #{ApplicationHelper.time_label(opened['at'])}. " \
      "Saisis un relevé en fermant : il sert à mesurer l'aération.", wait.to_s
    )
  end

  it 'leaves it alone on the next runs of the same airing' do
    2.times { described_class.sync(airing, now) }
    expect(described_class).to calls(CloseReminder::CREATE).once
  end

  it 'deletes it once a reading ends the airing' do
    described_class.sync(airing, now)
    closed = reading(21.0, 43.0, time: ApplicationHelper.iso(now))

    expect(described_class.sync(airing([opened, closed]), now)).to eq('enabled' => true)
    expect(described_class).to have_received(:osascript).with(CloseReminder::DELETE, id)
  end

  it 'replaces it when the opening reading is corrected' do
    described_class.sync(airing, now)
    described_class.sync(airing([opened.merge('humidity' => 48.0)]), now)
    expect(described_class).to calls(CloseReminder::DELETE).once
    expect(described_class).to calls(CloseReminder::CREATE).twice
  end

  it 'keeps it while outdoor data is missing' do
    described_class.sync(airing, now)
    expect(described_class.sync({ error: 'Délai réseau dépassé (5 s)' }, now)).to include('id' => id)
    expect(described_class).not_to calls(CloseReminder::DELETE)
  end

  it 'sets none for a reading entered after its closing time' do
    late = reading(21.0, 46.0, time: ApplicationHelper.iso(now - 7200), windows: 'one')
    expect(described_class.sync(airing([late]), now)).not_to include('id')
    expect(described_class).not_to have_received(:osascript)
  end

  it 'is on by default; turned off, it deletes the reminder and sets none until turned back on' do
    expect(described_class.read).to eq('enabled' => true)
    described_class.sync(airing, now)

    described_class.toggle
    expect(described_class.sync(airing, now)).to eq('enabled' => false)
    expect(described_class).to have_received(:osascript).with(CloseReminder::DELETE, id)

    described_class.toggle
    expect(described_class.sync(airing, now)).to include('enabled' => true, 'id' => id)
    expect(described_class).to calls(CloseReminder::CREATE).twice
  end

  it 'reports Reminders failing, and tries again at the next run' do
    allow(described_class).to receive(:osascript).and_raise(CloseReminder::Failed, 'Rappels ne répond pas (30 s)')
    expect(described_class.sync(airing, now)).to eq(
      'enabled' => true, 'error' => 'Rappel pour fermer impossible : Rappels ne répond pas (30 s)'
    )

    allow(described_class).to receive(:osascript).and_return(id)
    expect(described_class.sync(airing, now)).to include('id' => id)
  end

  describe '.failure' do
    it 'says where to allow access to Reminders' do
      output = "0:251: execution error: Not authorized to send Apple events to Reminders. (-1743)\n"
      expect(described_class.failure(output)).to start_with("autorise l'accès à Rappels")
    end

    it "keeps other errors, without osascript's position" do
      output = "0:40: execution error: Reminders got an error: AppleEvent timed out. (-1712)\n"
      expect(described_class.failure(output)).to eq('Reminders got an error: AppleEvent timed out. (-1712)')
    end
  end
end
