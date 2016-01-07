require 'spec_helper'

describe Gitlab::Metrics::Transaction do
  let(:transaction) { described_class.new }

  describe '#duration' do
    it 'returns the duration of a transaction in seconds' do
      transaction.run { sleep(0.5) }

      expect(transaction.duration).to be >= 0.5
    end
  end

  describe '#run' do
    it 'yields the supplied block' do
      expect { |b| transaction.run(&b) }.to yield_control
    end

    it 'stores the transaction in the current thread' do
      transaction.run do
        expect(Thread.current[described_class::THREAD_KEY]).to eq(transaction)
      end
    end

    it 'removes the transaction from the current thread upon completion' do
      transaction.run { }

      expect(Thread.current[described_class::THREAD_KEY]).to be_nil
    end
  end

  describe '#add_metric' do
    it 'adds a metric to the transaction' do
      expect(Gitlab::Metrics::Metric).to receive(:new).
        with('rails_foo', { number: 10 }, {})

      transaction.add_metric('foo', number: 10)
    end
  end

  describe '#increment' do
    it 'increments a counter' do
      transaction.increment(:time, 1)
      transaction.increment(:time, 2)

      expect(transaction).to receive(:add_metric).
        with('transactions', { duration: 0.0, time: 3 }, {})

      transaction.track_self
    end
  end

  describe '#set' do
    it 'sets a value' do
      transaction.set(:number, 10)

      expect(transaction).to receive(:add_metric).
        with('transactions', { duration: 0.0, number: 10 }, {})

      transaction.track_self
    end
  end

  describe '#add_tag' do
    it 'adds a tag' do
      transaction.add_tag(:foo, 'bar')

      expect(transaction.tags).to eq({ foo: 'bar' })
    end
  end

  describe '#finish' do
    it 'tracks the transaction details and submits them to Sidekiq' do
      expect(transaction).to receive(:track_self)
      expect(transaction).to receive(:submit)

      transaction.finish
    end
  end

  describe '#track_self' do
    it 'adds a metric for the transaction itself' do
      expect(transaction).to receive(:add_metric).
        with('transactions', { duration: transaction.duration }, {})

      transaction.track_self
    end
  end

  describe '#submit' do
    it 'submits the metrics to Sidekiq' do
      transaction.track_self

      expect(Gitlab::Metrics).to receive(:submit_metrics).
        with([an_instance_of(Hash)])

      transaction.submit
    end
  end
end
