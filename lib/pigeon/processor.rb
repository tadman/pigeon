class Pigeon::Processor
  # == Exceptions ===========================================================
  
  class AlreadyBoundToQueue < Exception
  end
  
  # == Constants ============================================================

  # == Properties ===========================================================
  
  attr_reader :task
  attr_reader :id

  # == Class Methods ========================================================

  # == Instance Methods =====================================================
  
  def initialize(queue = nil, &filter)
    @id = Pigeon::Support.unique_id
    @lock = Mutex.new
    @filter = filter || lambda { |task| true }
    
    self.queue = queue if (queue)
    
    switch_to_next_task!
  end
  
  def queue=(queue)
    raise AlreadyBoundToQueue, @queue if (@queue)
    
    @queue = queue

    @queue.observe do |task|
      @lock.synchronize do
        if (!@task and @filter.call(task))
          @task = queue.claim(task)
      
          @task.run! do
            switch_to_next_task!
          end
        end
      end
    end
  end
  
  def accept?(task)
    @filter.call(task)
  end
  
  def task?
    !!@task
  end
  
protected
  def switch_to_next_task!
    @lock.synchronize do
      @task = nil

      if (@task = @queue.pop(&@filter))
        @task.run! do
          switch_to_next_task!
        end
      end
    end
  end
end
