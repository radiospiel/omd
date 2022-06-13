module OMD::Processors
  extend self

  H = OMD::H

  def comment(intro, code_block, writer:); end

  def dot(_filters, code_block, writer:)
    File.write("omd.dot", code_block)

    H.sh! "dot -Tpng -Gsize=16,16\! -Gdpi=72  -o dot.png omd.dot"

    writer.image "dot.png", alt: "dot"
  end

  def ruby(_filters, code_block, writer:)
    gemfile = ENV["BUNDLE_GEMFILE"]

    if gemfile
      ENV["BUNDLE_GEMFILE"] = nil
    end

    File.write("omd.rb", code_block, permissions: 0o755)

    result = H.sh! "ruby ./omd.rb"
    writer.code_block result, lang: "ruby"
  ensure
    ENV["BUNDLE_GEMFILE"] = nil if gemfile
  end

  def bob(_filters, code_block, writer:)
    File.write("omd.bob", code_block)
    OMD::H.sh! "svgbob omd.bob -o bob.svg"
    writer.image "bob.svg", alt: "svgbob"
  end

  def mermaid(_filters, code_block, writer:)
    H.which! "mmdc", "brew install mermaid-cli"

    File.write("omd.mmd", code_block)
    H.sh! "mmdc -i omd.mmd -o mermaid.png"
    writer.image "mermaid.png", alt: "mermaid"
  end

  def bash(filters, code_block, writer:)
    tmp_file = ".omd-#{$$}.sh"
    File.write tmp_file, <<~BASH, permissions: 0o755
      #!/bin/bash
      set -eu -o pipefail
      #{code_block}
    BASH

    result = H.sh! "./#{tmp_file}"
    if filters.length == 1
      writer.code_block result, lang: filters.first
    else
      writer.code_block result
    end
  ensure
    FileUtils.rm_f tmp_file
  end

  def cc(_filters, code_block, writer:)
    H.which! "cc"

    File.write("omd.cc", code_block)

    H.sh! "cc -Wall omd.cc"

    result = H.sh! "./a.out"
    writer.code_block result
  end

  def sql(_filters, code_block, writer:)
    H.which! "sqlite3", "brew install sqlite3"

    File.write("omd.sql", code_block)
    success = H.sh! "sqlite3 -noheader -separator $'\t' < omd.sql"
    writer.table(success, separator: "\t")
  end
end
