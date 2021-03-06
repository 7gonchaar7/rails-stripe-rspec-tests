# Note for rails-stripe-memberships-saas app : this test can be ignored, removed, etc.
# this is more of a test upon stripe_mock itself
require 'stripe_mock'

describe StripeMock do
  it 'overrides stripe request method' do
    StripeMock.start
    Stripe.request(:xtest, '/', 'abcde') # no error
    StripeMock.stop
  end

  it 'reverts overriding stripe request method' do
    StripeMock.start
    Stripe.request(:xtest, '/', 'abcde') # no error
    expect { Stripe.request(:x, '/', 'abcde') }.not_to raise_error { |e|
      expect(e.http_status).to eq 404
    }
    StripeMock.stop
  end

  it 'does not persist data between mock sessions' do
    StripeMock.start
    StripeMock.instance.customers[:x] = 9
    StripeMock.stop
    StripeMock.start
    expect(StripeMock.instance.customers[:x]).to be_nil
    expect(StripeMock.instance.customers.keys.length).to eq 0
    StripeMock.stop
  end

  it 'throws an error when trying to prepare an error before starting' do
    StripeMock.start
    expect { StripeMock.prepare_error(StandardError.new) }.not_to raise_error { |e|
      expect(e).to be_a(StripeMock::UnstartedStateError)
    }
    expect { StripeMock.prepare_card_error(:card_declined) }.not_to raise_error { |e|
      expect(e).to be_a(StripeMock::UnstartedStateError)
    }
    StripeMock.stop
  end

  describe 'Live Testing' do
    after { StripeMock.instance_variable_set(:@state, 'ready') }

    it 'sets the default test strategy' do
      StripeMock.stop
      expect(StripeMock.state).to eq 'ready'
      StripeMock.toggle_live(true)
      expect(StripeMock.create_test_helper).to be_a StripeMock::TestStrategies::Live
      StripeMock.toggle_live(false)
      expect(StripeMock.create_test_helper).to be_a StripeMock::TestStrategies::Mock
      StripeMock.stop
    end

    it 'does not start when live' do
      StripeMock.stop
      expect(StripeMock.state).to eq 'ready'
      StripeMock.toggle_live(true)
      expect(StripeMock.state).to eq 'live'
      expect(StripeMock.start).to eq false
      expect(StripeMock.start_client).to eq false
    end

    it 'can be undone' do
      StripeMock.stop
      StripeMock.toggle_live(false)
      expect(StripeMock.state).to eq 'ready'
      expect(StripeMock.start).to_not eq false
      StripeMock.stop
    end

    it 'cannot be toggled when already started' do
      StripeMock.start
      expect { StripeMock.toggle_live(true) }.to raise_error { |e|
        expect(e).to be_a(RuntimeError)
      }
      StripeMock.stop
      StripeMock.instance_variable_set(:@state, 'remote')
      expect { StripeMock.toggle_live(true) }.to raise_error { |e|
        expect(e).to be_a(RuntimeError)
      }
    end
  end

  describe 'Test Helper Strategies' do
    before { StripeMock.instance_variable_set('@__test_strat', nil) }

    it 'uses mock by default' do
      helper = StripeMock.create_test_helper
      expect(helper).to be_a StripeMock::TestStrategies::Mock
    end

    it 'can specify which strategy to use' do
      helper = StripeMock.create_test_helper(:live)
      expect(helper).to be_a StripeMock::TestStrategies::Live
      helper = StripeMock.create_test_helper(:mock)
      expect(helper).to be_a StripeMock::TestStrategies::Mock
    end

    it 'throws an error on an unknown strategy' do
      expect { StripeMock.create_test_helper(:lol) }.to raise_error { |e|
        expect(e).to be_a(RuntimeError)
      }
    end

    it 'can configure the default strategy' do
      StripeMock.set_default_test_helper_strategy(:live)
      helper = StripeMock.create_test_helper
      expect(helper).to be_a StripeMock::TestStrategies::Live
    end

    it 'can override a set default strategy' do
      StripeMock.set_default_test_helper_strategy(:live)
      helper = StripeMock.create_test_helper(:mock)
      expect(helper).to be_a StripeMock::TestStrategies::Mock
    end
  end
end
