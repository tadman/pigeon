require File.expand_path(File.join(*%w[ .. helper ]), File.dirname(__FILE__))

class ExampleTask < Pigeon::Task
  attr_accessor :triggers
  
  def state_initialized!
    transition_to_state(:state1)
  end

  def state_state1!
    transition_to_state(:state2)
  end

  def state_state2!
    transition_to_state(:state3)
    
    dispatch do
      sleep(3)
      transition_to_state(:state4)
    end
  end
  
  def state_state4!
    transition_to_state(:finished)
  end
  
  def after_initialized
    @triggers = [ :after_initialized ]
  end
  
  def before_state(state)
    @triggers << state
  end
  
  def after_finished
    @triggers << :after_finished
  end
end

class FailingTask < Pigeon::Task
  def state_initialized!
    invalid_method!
  end
end

class PigeonTaskTest < Test::Unit::TestCase
  def setup
    @engine = Pigeon::Engine.new

    Pigeon::Engine.register_engine(@engine)
  end
  
  def teardown
    Pigeon::Engine.unregister_engine(@engine)
  end
  
  def test_empty_task
    task = Pigeon::Task.new
    
    reported = 0
    
    task.run! do
      reported = 1
    end

    assert_eventually(5) do
      task.finished? and reported > 0
    end
    
    assert_equal 1, reported
    assert_equal :finished, task.state

    assert_equal nil, task.exception
    
    assert_equal @engine.object_id, task.engine.object_id
  end

  def test_alternate_engine
    engine = Pigeon::Engine.new
    task = Pigeon::Task.new(nil, engine)
    
    assert_equal engine.object_id, task.engine.object_id
  end
  
  def test_example_task
    task = ExampleTask.new
    
    callbacks = [ ]
    
    task.run! do |state|
      callbacks << state
    end
    
    assert_eventually(5) do
      task.finished?
    end
    
    assert_equal nil, task.exception
    
    assert_equal :finished, task.state

    expected_triggers = [
      :after_initialized,
      :initialized,
      :state1,
      :state2,
      :state3,
      :state4,
      :finished,
      :after_finished
    ]
    
    assert_equal expected_triggers, task.triggers

    expected_callbacks = [
      :initialized,
      :state1,
      :state2,
      :state3,
      :state4,
      :finished
    ]

    assert_equal expected_callbacks, callbacks
  end

  def test_failing_task
    task = FailingTask.new
    
    reported = false
    
    task.run! do
      reported = true
    end
    
    assert_eventually(5) do
      task.failed? and reported
    end

    assert task.exception?
  end
  
  def test_with_context
    options = {
      :example => 'example1',
      :optional => 1
    }.freeze
    
    task = Pigeon::Task.new(options)
    
    assert_equal options, task.context
    
    task.context = 'test'
    
    assert_equal 'test', task.context
  end

  def test_block_notification
    task = Pigeon::Task.new

    states_triggered = [ ]

    task.run! do |state|
      states_triggered << state
    end
    
    assert_eventually(5) do
      task.finished?
    end
    
    assert_equal [ :initialized, :finished ], states_triggered
  end

  def test_priority_order
    tasks = (0..10).collect do
      task = Pigeon::Task.new

      # Trigger generation of default priority value
      task.priority

      task 
    end
    
    assert_equal tasks.collect(&:object_id), tasks.sort.collect(&:object_id)
  end
end
