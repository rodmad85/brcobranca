# frozen_string_literal: true

module Brcobranca
  module Remessa
    module Cnab400
      class Sicredi < Brcobranca::Remessa::Cnab400::Base
        attr_accessor :byte_idt, :posto, :modalidade_carteira

        validates_presence_of :byte_idt, :posto, :documento_cedente,
                              message: 'não pode estar em branco.'

        validates_length_of :byte_idt, is: 1, message: 'deve ser 1 digito (2-9 se gerado pelo beneficiario)'
        validates_length_of :posto, maximum: 2, message: 'deve ter 2 digitos.'
        validates_length_of :documento_cedente, minimum: 11, maximum: 14, message: 'deve ter entre 11 e 14 digitos.'
        validates_length_of :carteira, is: 1, message: 'deve ter 1 digito (A - Simples).'

        def initialize(campos = {})
          campos = {
            carteira: 'A',
            aceite: 'N',
            modalidade_carteira: 'A'
          }.merge!(campos)
          super(campos)
        end

        def cod_banco
          '748'
        end

        def nome_banco
          'SICREDI'.ljust(15, ' ')
        end

        def info_conta
          codigo_beneficiario + documento_cedente_sem_formatacao
        end

        def codigo_beneficiario
          (@codigo_beneficiario || '00000').to_s.rjust(5, '0')
        end

        def codigo_beneficiario=(valor)
          @codigo_beneficiario = valor
        end

        def documento_cedente_sem_formatacao
          documento_cedente.to_s.gsub(/[^0-9]/, '').rjust(14, '0')
        end

        def complemento
          (' ' * 273) + '2.00'
        end

        def digito_agencia
          ' '
        end

        def monta_header
          header = +'0'                                         # 001
          header << '1'                                         # 002
          header << 'REMESSA'                                   # 003-009
          header << '1 '                                        # 010-011
          header << 'COBRANCA'                                  # 012-019
          header << (' ' * 7)                                   # 020-026
          header << codigo_beneficiario                         # 027-031
          header << documento_cedente_sem_formatacao            # 032-045
          header << (' ' * 31)                                  # 046-076
          header << cod_banco                                   # 077-079
          header << 'SICREDI'.ljust(15, ' ')                    # 080-094
          header << data_geracao_aaaammdd                       # 095-102
          header << (' ' * 8)                                   # 103-110
          header << sequencial_remessa.to_s.rjust(7, '0')       # 111-117
          header << (' ' * 273)                                 # 118-390
          header << '2.00'                                      # 391-394
          header << '000001'                                    # 395-400
          header
        end

        def data_geracao_aaaammdd
          Date.current.strftime('%Y%m%d')
        end

        def monta_detalhe(pagamento, sequencial)
          raise Brcobranca::RemessaInvalida, pagamento if pagamento.invalid?

          detalhe = +'1'                                                    # 001
          detalhe << 'A'                                                    # 002
          detalhe << carteira.to_s.ljust(1, ' ')                            # 003
          detalhe << 'A'                                                    # 004
          detalhe << ' '                                                    # 005
          detalhe << ' '                                                    # 006
          detalhe << (' ' * 10)                                             # 007-016
          detalhe << 'A'                                                    # 017
          detalhe << tipo_desconto(pagamento)                               # 018
          detalhe << tipo_juros(pagamento)                                  # 019
          detalhe << (' ' * 28)                                             # 020-047
          detalhe << formata_nosso_numero(pagamento.nosso_numero)           # 048-056
          detalhe << (' ' * 6)                                              # 057-062
          detalhe << data_instrucao                                         # 063-070
          detalhe << ' '                                                    # 071
          detalhe << 'N'                                                    # 072
          detalhe << ' '                                                    # 073
          detalhe << 'B'                                                    # 074
          detalhe << '01'                                                   # 075-076
          detalhe << '01'                                                   # 077-078
          detalhe << (' ' * 4)                                              # 079-082
          detalhe << pagamento.formata_valor_desconto(10)                   # 083-092
          detalhe << pagamento.formata_percentual_multa(4)                  # 093-096
          detalhe << (' ' * 12)                                             # 097-108
          detalhe << pagamento.identificacao_ocorrencia                     # 109-110
          detalhe << pagamento.numero.to_s.ljust(10, ' ')                   # 111-120
          detalhe << pagamento.data_vencimento.strftime('%d%m%y')           # 121-126
          detalhe << pagamento.formata_valor(13)                            # 127-139
          detalhe << (' ' * 2)                                              # 140-141
          detalhe << (' ' * 6)                                              # 142-148
          detalhe << especie_titulo(pagamento)                              # 149
          detalhe << aceite                                                 # 150
          detalhe << pagamento.data_emissao.strftime('%d%m%y')              # 151-156
          detalhe << protesto_auto(pagamento)                               # 157-158
          detalhe << dias_protesto(pagamento)                               # 159-160
          detalhe << pagamento.formata_valor_mora(13)                       # 161-173
          detalhe << pagamento.formata_data_desconto                        # 174-179
          detalhe << pagamento.formata_valor_desconto(13)                   # 180-192
          detalhe << '00'                                                   # 193-194
          detalhe << '00'                                                   # 195-196
          detalhe << ('0' * 9)                                              # 197-205
          detalhe << pagamento.formata_valor_abatimento(13)                 # 206-218
          detalhe << pagamento.identificacao_sacado                         # 219
          detalhe << '0'                                                    # 220
          detalhe << pagamento.documento_sacado.to_s.rjust(14, '0')         # 221-234
          detalhe << pagamento.nome_sacado.format_size(40)                  # 235-274
          detalhe << pagamento.endereco_sacado.format_size(40)              # 275-314
          detalhe << ('0' * 5)                                              # 315-319
          detalhe << ('0' * 6)                                              # 320-325
          detalhe << ' '                                                    # 326
          detalhe << pagamento.cep_sacado                                   # 327-334
          detalhe << ('0' * 5)                                              # 335-339
          detalhe << ('0' * 14)                                             # 340-353
          detalhe << (' ' * 41)                                             # 354-394
          detalhe << sequencial.to_s.rjust(6, '0')                          # 395-400
          detalhe
        end

        def monta_trailer(sequencial)
          +'9' + (' ' * 393) + sequencial.to_s.rjust(6, '0')
        end

        def formata_nosso_numero(nosso_numero)
          nosso_numero.to_s.somente_numeros.rjust(9, '0')
        end

        def tipo_desconto(pagamento)
          return 'B' if pagamento.valor_desconto.to_f.positive? && pagamento.cod_desconto == '2'
          'A'
        end

        def tipo_juros(pagamento)
          return 'B' if %w[1 2].include?(pagamento.tipo_mora)
          'A'
        end

        MAPA_ESPECIE = {
          '01' => 'A', '02' => 'B', '03' => 'C', '04' => 'D',
          '05' => 'E', '06' => 'G', '07' => 'H', '08' => 'I',
          '09' => 'J', '10' => 'K', '11' => 'O'
        }.freeze

        def especie_titulo(pagamento)
          especie = pagamento.especie_titulo.to_s
          MAPA_ESPECIE[especie] || especie[0] || 'A'
        end

        def protesto_auto(pagamento)
          protesto = pagamento.codigo_protesto.to_s
          if %w[1 2 3 4 5 6 7 8 9].include?(protesto)
            '06'
          else
            '00'
          end
        end

        def dias_protesto(pagamento)
          pagamento.dias_protesto.to_s.rjust(2, '0')
        end

        def data_instrucao
          Date.current.strftime('%Y%m%d')
        end
      end
    end
  end
end
