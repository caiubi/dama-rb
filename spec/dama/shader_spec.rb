require "spec_helper"

# Custom WGSL fragment shader that tints everything red.
RED_TINT_SHADER = <<~WGSL.freeze
  @fragment
  fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
      let tex_color = textureSample(t_diffuse, s_diffuse, in.uv);
      return vec4<f32>(1.0, 0.0, 0.0, 1.0) * tex_color * in.color;
  }
WGSL

RSpec.describe "Custom shader support" do # rubocop:disable RSpec/DescribeClass
  # Single engine lifecycle for all shader tests to avoid GPU state corruption.
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    @backend = Dama::Backend::Native.new
    config = Dama::Configuration.new(width: 64, height: 64, headless: true)
    @backend.initialize_engine(configuration: config)
  end

  after(:all) { @backend.shutdown } # rubocop:disable RSpec/BeforeAfterAll

  let(:backend) { @backend }

  describe "Node shader DSL" do
    it "declares shaders with inline source" do
      node_class = Class.new(Dama::Node) do
        shader :tint, source: RED_TINT_SHADER
      end

      expect(node_class.shader_declarations).to have_key(:tint)
      expect(node_class.shader_declarations[:tint][:source]).to eq(RED_TINT_SHADER)
    end

    it "declares shaders from a file path" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "glow.wgsl")
        File.write(path, RED_TINT_SHADER)

        node_class = Class.new(Dama::Node) do
          shader :glow, path: path
        end

        expect(node_class.shader_declarations[:glow][:path]).to eq(path)
      end
    end

    it "loads shaders and provides handle via named accessor" do
      node_class = Class.new(Dama::Node) do
        shader :tint, source: RED_TINT_SHADER
      end

      node = node_class.new
      node.load_shaders(backend:)

      expect(node.tint).to be_a(Integer)
      expect(node.tint).to be > 0
    end

    it "loads shaders from file path" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "effect.wgsl")
        File.write(path, RED_TINT_SHADER)

        node_class = Class.new(Dama::Node) do
          shader :effect, path: path
        end

        node = node_class.new
        node.load_shaders(backend:)

        expect(node.effect).to be > 0
      end
    end

    it "unloads shaders" do
      node_class = Class.new(Dama::Node) do
        shader :tint, source: RED_TINT_SHADER
      end

      node = node_class.new
      node.load_shaders(backend:)
      handle = node.tint

      expect { node.unload_shaders(backend:) }.not_to raise_error
      expect { backend.unload_shader(handle:) }.not_to raise_error
    end
  end

  describe "DrawContext with shader: param" do
    let(:node_class) do
      Class.new(Dama::Node) do
        shader :tint, source: RED_TINT_SHADER
        attribute :label, default: "test"
      end
    end

    let(:node) do
      n = node_class.new
      n.load_shaders(backend:)
      n
    end

    let(:context) { Dama::Node::DrawContext.new(node:, backend:) }

    it "renders rect with custom shader" do
      backend.begin_frame
      backend.clear(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
      context.rect(0, 0, 64, 64, r: 1.0, g: 1.0, b: 1.0, a: 1.0, shader: node.tint)
      backend.end_frame

      Dir.mktmpdir do |dir|
        path = File.join(dir, "shader_rect.png")
        backend.screenshot(output_path: path)
        img = ChunkyPNG::Image.from_file(path)
        # The red tint shader makes everything red.
        red = ChunkyPNG::Color.r(img[32, 32])
        green = ChunkyPNG::Color.g(img[32, 32])
        expect(red).to be > 200
        expect(green).to be < 50
      end
    end

    it "renders circle with custom shader" do
      backend.begin_frame
      backend.clear(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
      context.circle(32, 32, 20, r: 1.0, g: 1.0, b: 1.0, a: 1.0, shader: node.tint)
      backend.end_frame

      Dir.mktmpdir do |dir|
        path = File.join(dir, "shader_circle.png")
        backend.screenshot(output_path: path)
        img = ChunkyPNG::Image.from_file(path)
        red = ChunkyPNG::Color.r(img[32, 32])
        expect(red).to be > 200
      end
    end

    it "renders triangle with custom shader" do
      backend.begin_frame
      backend.clear(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
      context.triangle(32, 0, 0, 63, 63, 63, r: 1.0, g: 1.0, b: 1.0, a: 1.0, shader: node.tint)
      backend.end_frame

      Dir.mktmpdir do |dir|
        path = File.join(dir, "shader_tri.png")
        backend.screenshot(output_path: path)
        img = ChunkyPNG::Image.from_file(path)
        red = ChunkyPNG::Color.r(img[32, 40])
        expect(red).to be > 200
      end
    end

    it "reverts to default shader after with_shader block" do
      backend.begin_frame
      backend.clear(r: 0.0, g: 0.0, b: 0.0, a: 1.0)
      # First shape with shader, second without — second should be normal.
      context.rect(0, 0, 32, 64, r: 1.0, g: 1.0, b: 1.0, a: 1.0, shader: node.tint)
      context.rect(32, 0, 32, 64, r: 0.0, g: 1.0, b: 0.0, a: 1.0)
      backend.end_frame

      Dir.mktmpdir do |dir|
        path = File.join(dir, "shader_revert.png")
        backend.screenshot(output_path: path)
        img = ChunkyPNG::Image.from_file(path)
        # Left half: tinted red. Right half: green (no shader).
        left_green = ChunkyPNG::Color.g(img[16, 32])
        right_green = ChunkyPNG::Color.g(img[48, 32])
        expect(left_green).to be < 50
        expect(right_green).to be > 200
      end
    end
  end

  describe "Backend::Native shader methods" do
    it "load_shader returns a handle > 0" do
      handle = backend.load_shader(source: RED_TINT_SHADER)
      expect(handle).to be > 0
    end

    it "unload_shader doesn't raise" do
      handle = backend.load_shader(source: RED_TINT_SHADER)
      expect { backend.unload_shader(handle:) }.not_to raise_error
    end

    it "set_shader doesn't raise" do
      handle = backend.load_shader(source: RED_TINT_SHADER)
      expect { backend.set_shader(handle:) }.not_to raise_error
      backend.set_shader(handle: 0)
    end
  end

  describe "CommandBuffer#push_set_shader" do
    it "adds a set_shader command to the buffer" do
      buf = Dama::CommandBuffer.new
      buf.push_set_shader(shader_handle: 42)

      data = buf.to_a
      expect(data).to eq([5.0, 42.0])
    end
  end

  describe "Scene integration" do
    it "loads shaders during composition and unloads on remove" do
      node_class = Class.new(Dama::Node) do
        shader :tint, source: RED_TINT_SHADER
      end
      stub_const("ShaderNode", node_class)

      scene_class = Class.new(Dama::Scene) do
        compose { add ShaderNode, as: :glowing }
      end

      registry = Dama::Registry.new
      scene = scene_class.new(registry:, backend:)
      scene.perform_compose

      expect(scene.glowing.tint).to be > 0

      scene.remove(:glowing)
    end
  end
end
