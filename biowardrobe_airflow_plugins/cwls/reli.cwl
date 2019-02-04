cwlVersion: v1.0
class: Workflow


requirements:
  - class: SubworkflowFeatureRequirement
  - class: InlineJavascriptRequirement
    expressionLib:
    - var filter = function(data, criteria) {
            var results = [];
            var dataParsed = JSON.parse(data);
            for (var i = 0; i < dataParsed.length; i++){
                var item = {};
                item.class = "File";
                item.path = dataParsed[i][criteria];
                results.push(item);
            };
            return results;
          };

inputs:

  snp_ld_folder:
    type: Directory
    label: "Folder to include phenotype SNP and linkage disequilibrium files"
    doc: |
      Phenotype SNP file (BED) and linkage disequilibrium file (TXT) are
      considered as a pair if they belong to the same directory level.
      If there are more then one SNP and one LD file in the same folder,
      the ones with the same basename are groupped together

  islands_bed_file:
    type: File
    label: "Islands file"
    format: "http://edamontology.org/format_3003"
    doc: "Islands file, BED"

  chrom_length_file:
    type: File
    label: "Chromosome length file"
    format: "http://edamontology.org/format_2330"
    doc: "Chromosome length file, TXT"

  null_model_file:
    type: File
    label: "Null model file"
    format: "http://edamontology.org/format_2330"
    doc: "Null model file, TXT"

  dbsnp_file:
    type: File
    label: "dbSNP table file"
    format: "http://edamontology.org/format_2330"
    doc: "dbSNP table file"


outputs:

  overlaps_files:
    type: File[]
    label: "Overlaps output files array"
    doc: "Output files array from completed RELI analysis"
    outputSource: reli_scatter/overlaps_files

  stats_files:
    type: File[]
    label: "Statistics output files array"
    doc: "Statistics output files array from completed RELI analysis"
    outputSource: reli_scatter/stats_files


steps:

  group_snp_and_ld:
    in:
      snp_ld_folder: snp_ld_folder
    out: [snp_bed_files, linkage_files]
    run:
      cwlVersion: v1.0
      class: CommandLineTool
      requirements:
        - class: DockerRequirement
          dockerPull: biowardrobe2/scidap:v0.0.3
      inputs:
        script:
          type: string?
          default: |
            # !/usr/bin/env python
            import sys, re, os
            from json import dumps
            def get_snp_and_ld_files(current_dir):
                selected_files = []
                for root, dirs, files in os.walk(current_dir):
                    for file in files:
                        if re.match(".*\.snp$", file):
                            snp_file_location = os.path.join(root, file)
                            ld_file_location = os.path.splitext(snp_file_location)[0] + ".ld"
                            if os.path.isfile(ld_file_location):
                                selected_files.append({"snp": snp_file_location, "ld": ld_file_location})
                return selected_files
            print(dumps(get_snp_and_ld_files(sys.argv[1]), indent=4))
          inputBinding:
            position: 5
        snp_ld_folder:
          type: Directory
          inputBinding:
            position: 6
      outputs:
        snp_bed_files:
          type: File[]
          outputBinding:
            loadContents: true
            glob: "result.json"
            outputEval: $(filter(self[0].contents, "snp"))
        linkage_files:
          type: File[]
          outputBinding:
            loadContents: true
            glob: "result.json"
            outputEval: $(filter(self[0].contents, "ld"))
      stdout: "result.json"
      baseCommand: [python, "-c"]

  reli_scatter:
    in:
      snp_bed_files: group_snp_and_ld/snp_bed_files
      linkage_files: group_snp_and_ld/linkage_files
      islands_bed_file: islands_bed_file
      chrom_length_file: chrom_length_file
      null_model_file: null_model_file
      dbsnp_file: dbsnp_file
    out: [overlaps_files, stats_files]
    run:
      cwlVersion: v1.0
      class: Workflow
      requirements:
      - class: ScatterFeatureRequirement
      inputs:
        snp_bed_files:
          type: File[]
        linkage_files:
          type: File[]
        islands_bed_file:
          type: File
        chrom_length_file:
          type: File
        null_model_file:
          type: File
        dbsnp_file:
          type: File
      outputs:
        overlaps_files:
          type: File[]
          outputSource: reli/overlaps_file
        stats_files:
          type: File[]
          outputSource: reli/stats_file
      steps:
        reli:
          in:
            snp_bed_file: snp_bed_files
            linkage_file: linkage_files
            islands_bed_file: islands_bed_file
            chrom_length_file: chrom_length_file
            null_model_file: null_model_file
            dbsnp_file: dbsnp_file
          scatter:
            - snp_bed_file
            - linkage_file
          scatterMethod: dotproduct
          out: [overlaps_file, stats_file]
          run:
            cwlVersion: v1.0
            class: CommandLineTool
            requirements:
              - class: InlineJavascriptRequirement
              - class: DockerRequirement
                dockerPull: weirauchlab/reli:v0.0.2
            inputs:
              snp_bed_file:
                type: File
                inputBinding:
                  prefix: "--snp"
              linkage_file:
                type: File
                inputBinding:
                  prefix: "--ld"
              islands_bed_file:
                type: File
                inputBinding:
                  prefix: "--target"
              chrom_length_file:
                type: File
                inputBinding:
                  prefix: "--build"
              null_model_file:
                type: File
                inputBinding:
                  prefix: "--null"
              dbsnp_file:
                type: File
                inputBinding:
                  prefix: "--dbsnp"
              match_flag:
                type: boolean?
                inputBinding:
                  prefix: "--match"
                default: True
              permutation:
                type: int?
                inputBinding:
                  prefix: "--rep"
                default: 2000
              correction_multiplier:
                type: int?
                inputBinding:
                  prefix: "--corr"
                default: 1
              phenotype_name:
                type: string?
                inputBinding:
                  prefix: "--phenotype"
                default: "."
              ancestry_name:
                type: string?
                inputBinding:
                  prefix: "--ancestry"
                default: "."
            outputs:
              overlaps_file:
                type: File
                outputBinding:
                  glob: "*.overlaps"
              stats_file:
                type: File
                outputBinding:
                  glob: "*.stats"
            baseCommand: ["RELI", "--out", "."]