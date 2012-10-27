module Qor
  module Dsl
    class Node
      attr_accessor :name, :config, :parent, :children, :data, :options, :block, :all_nodes, :dummy

      def initialize(name=nil, options={})
        self.name   = name
        self.add_config(options[:config] || Qor::Dsl::Config.new('ROOT', self))
        self.dummy = options[:dummy]
      end

      ## Node Config
      def config_name
        config.__name
      end

      def config_options
        config.__options || {} rescue {}
      end

      def child_config(type)
        config.__children[type] || nil
      end

      def child_config_options(type)
        child_config(type).__options || {} rescue {}
      end

      def dummy?
        dummy
      end

      def is_node?(cname=nil, sname=nil)
        (cname.nil? || (config_name.to_s == cname.to_s)) && (sname.nil? || (name.to_s == sname.to_s))
      end

      def root?
        root == self
      end

      def root
        parent ? parent.root : self
      end

      def parents
        parent ? [parent, parent.parents].flatten : []
      end

      def options
        return @options if @options.is_a?(Hash)
        return data[-1] if data.is_a?(Array) && data[-1].is_a?(Hash)
        return data if data.is_a?(Hash)
        return config_options[:default_options] || {} if dummy?
        {}
      end

      def value
        ((config.__children.size > 0 || block.nil?) ? (options[:value] || name) : block.call) ||
          (dummy? ? config_options[:default_value] : nil)
      end

      def block
        @block || (dummy? ? config_options[:default_block] : nil)
      end

      def add_config(config)
        self.config = config
        config.__node = self
      end

      def node(type, options={}, &blk)
        config.node(type, options, &blk)
      end

      def children
        @children ||= []
        @children = @children.flatten.compact
        @children
      end

      def add_child(child)
        child.parent = self
        children << child
        root.all_nodes ||= []
        root.all_nodes << child
      end

      def deep_find(type=nil, name=nil, &block)
        nodes = root.all_nodes
        nodes = nodes.select {|n| n.parents.include?(self) } unless root?
        find(type, name, nodes, &block)
      end

      def find(type=nil, name=nil, nodes=children, &block)
        results = nodes.select do |child|
          child.is_node?(type, name) && (block.nil? ? true : block.call(child))
        end

        results = parent.find(type, name, &block) if results.length == 0 && child_config_options(type)[:inherit]
        results = process_find_results(results, type)

        return results[0] if !name.nil? && results.is_a?(Array) && results.length == 1

        results
      end

      def first(type=nil, name=nil, &block)
        selected_children = find(type, name, &block)
        selected_children.is_a?(Array) ? selected_children[0] : selected_children
      end

      ## Inspect
      def inspect_name
        "{#{config_name}: #{name || 'nil'}}"
      end

      def to_s
        obj_options = {
          'name' => name,
          'parent' => parent && parent.inspect_name,
          'config' => config_name,
          'children' => children.map(&:inspect_name),
          'data' => data,
          'block' => block
        }
        Qor::Dsl.inspect_object(self, obj_options)
      end

      private
      def process_find_results(results, type)
        if results.length == 0 &&
          %w(default_options default_value default_block).any? {|x| child_config_options(type)[x.to_sym] }
          results = [Node.new(nil, :config => child_config(type), :dummy => true)]
        end
        results
      end
    end
  end
end
