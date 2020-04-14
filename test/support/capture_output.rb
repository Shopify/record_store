module CaptureOutput
  def setup
    super

    @original_stdout = $stdout
    @original_stderr = $stderr

    $stdout = @captured_stdout = StringIO.new
    $stderr = @captured_stderr = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
    $stdout = @original_stdout

    super
  end
end

Minitest::Test.send(:prepend, CaptureOutput)
