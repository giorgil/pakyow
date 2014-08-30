module Pakyow
  module Presenter
    class StringDoc
      attr_reader :structure

      TITLE_REGEX = /<title>(.*?)<\/title>/

      def initialize(html)
        @structure = StringDocParser.new(html).structure
      end

      def self.from_structure(structure, node: nil)
        instance = allocate
        instance.instance_variable_set(:@structure, structure)
        instance.instance_variable_set(:@node, node)
        return instance
      end

      def initialize_copy(original_doc)
        super
        @structure = Utils::Dup.deep(original_doc.structure)
      end

      def title
        title_search do |n, match|
          return match[1]
        end
      end

      def title=(title)
        title_search do |n, match|
          n.gsub!(TITLE_REGEX, "<title>#{title}</title>")
        end
      end

      def set_attribute(name, value)
        attributes[name.to_sym] = value
      end
      alias :update_attribute :set_attribute

      def get_attribute(name)
        attributes[name.to_sym]
      end

      def remove_attribute(name)
        attributes.delete(name.to_sym)
      end

      def remove
        @structure.delete_if { |n| n == node }
      end

      def clear
        node[2][0][2].clear
      end

      def text
        html.gsub(/<[^>]*>/, '')
      end

      def text=(text)
        clear
        node[2][0][2] << [text, {}, []]
      end

      def html
        StringDocRenderer.render(node[2][0][2])
      end

      def html=(html)
        clear
        node[2][0][2] << [html, {}, []]
      end

      def append(appendable_doc)
        #TODO make a helper that handles string or stringdoc
        if appendable_doc.is_a?(StringDoc)
          node[2][0][2].concat(appendable_doc.structure)
        else
          node[2][0][2] << appendable_doc.to_s
        end
      end

      def prepend(prependable_doc)
        if prependable_doc.is_a?(StringDoc)
          node[2][0][2].unshift(*prependable_doc.structure)
        else
          node[2][0][2].unshift(prependable_doc.to_s)
        end
      end

      def after(insertable_doc)
        if insertable_doc.is_a?(StringDoc)
          node << insertable_doc.structure
        else
          node << insertable_doc.to_s
        end
      end

      def before(insertable_doc)
        node.unshift(usable_doc(insertable_doc))
      end

      def replace(replacement_doc)
        doc = usable_doc(replacement_doc)
        index = @structure.index(node) || 0
        @structure.insert(index + 1, *doc)
        @structure.delete_at(index)
      end

      def scope(scope_name)
        scopes.select { |b| b[:scope] == scope_name }.map { |scope|
          scope[:doc]
        }
      end

      def prop(scope_name, prop_name)
        return [] unless scope = scopes.select { |s| s[:scope] == scope_name }[0]
        scope[:props].select { |p| p[:prop] == prop_name }.map { |prop|
          prop[:doc]
        }
      end

      def container(name)
        containers.fetch(name, {})[:doc]
      end

      def containers
        find_containers(@structure)
      end

      def partials
        find_partials(@structure)
      end

      def scopes
        find_scopes(@structure)
      end
      #TODO deprecate `bindings` throughout presenter
      alias :bindings :scopes

      def to_html
        StringDocRenderer.render(@structure)
      end
      alias :to_s :to_html

      def ==(o)
        #TODO do this without rendering
        # (in the case of comparing StringDoc to String Doc
        to_s == o.to_s
      end

      def node
        return @structure if @structure.empty?
        return @node || @structure[0]
      end

      private

      def title_search
        @structure.flatten.each do |n|
          next unless n.is_a?(String)
          if match = n.match(TITLE_REGEX)
            yield n, match
          end
        end
      end

      # Returns the structure representing the attributes for the node
      #
      def attributes
        node[1]
      end

      def usable_doc(doc)
        doc.is_a?(StringDoc) ? doc.structure : [[doc.to_s, {}, []]]
      end

      def find_containers(structure, containers = {})
        return {} if structure.empty?
        structure.inject(containers) { |s, e|
          if e[1].has_key?(:container)
            s[e[1][:container]] = { doc: StringDoc.from_structure(structure, node: e) }
          end
          find_containers(e[2], s)
          s
        } || {}
      end

      def find_partials(structure, partials = {})
        structure.inject(partials) { |s, e|
          if e[1].has_key?(:partial)
            s[e[1][:partial]] = StringDoc.from_structure(structure, node: e)
          end
          find_partials(e[2], s)
          s
        } || {}
      end

      def find_scopes(structure, scopes = [])
        ret_scopes = structure.inject(scopes) { |s, e|
          if e[1].has_key?(:'data-scope')
            s << {
              doc: StringDoc.from_structure(structure, node: e),
              scope: e[1][:'data-scope'].to_sym,
              props: find_props(e[2]),
              nested: find_scopes(e[2]),
            }
          end
          find_scopes(e[2], s)
          s
        } || []

        #TODO is this something we still want to support?
        # # find unscoped props
        # if !structure.empty? && !structure[0][1].has_key?(:'data-scope')
        #   ret_scopes.unshift({
        #     scope: nil,
        #     props: find_props(structure),
        #     nested: [],
        #   })
        # end

        ret_scopes
      end

      def find_props(structure, props = [])
        structure.inject(props) { |s, e|
          if e[1].has_key?(:'data-prop')
            s << {
              doc: StringDoc.from_structure(structure),
              prop: e[1][:'data-prop'].to_sym,
            }
          end
          unless e[1].has_key?(:'data-scope')
            find_props(e[2], s)
          end
          s
        } || []
      end
    end
  end
end