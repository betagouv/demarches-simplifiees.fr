require 'spec_helper'

describe StatsController, type: :controller do
  describe '#thirty_days_flow_hash' do
    before do
      FactoryGirl.create(:procedure, :created_at => 45.days.ago)
      FactoryGirl.create(:procedure, :created_at => 15.days.ago)
      FactoryGirl.create(:procedure, :created_at => 1.day.ago)

      @expected_hash = {}
      (30.days.ago.to_date..Time.now.to_date).each do |day|
        if [15.days.ago.to_date, 1.day.ago.to_date].include?(day)
          @expected_hash[day] = 1
        else
          @expected_hash[day] = 0
        end
      end
    end

    let (:association) { Procedure.all }

    subject { StatsController.new.send(:thirty_days_flow_hash, association) }

    it { expect(subject).to eq(@expected_hash) }
  end

  describe '#cumulative_hash' do
    before do
      FactoryGirl.create(:procedure, :created_at => 45.days.ago)
      FactoryGirl.create(:procedure, :created_at => 15.days.ago)
      FactoryGirl.create(:procedure, :created_at => 15.days.ago)
    end

    let (:association) { Procedure.all }

    subject { StatsController.new.send(:cumulative_hash, association) }

    it { expect(subject).to eq({
      45.days.ago.beginning_of_month => 1,
      15.days.ago.beginning_of_month => 3
    }) }
  end
end
