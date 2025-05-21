//-----------------------------------------------------------------------------------------------
// File        : pulser.sv
// Author      : Nico Canzani <ncanzani@student.ethz.ch>
// Description : Top-Level Wrapper for multiple Pulse Generators
//
// This module integrates multiple instances of the `pulser_core` module and exposes a unified
// register interface over the OBI (Open Bus Interface) protocol.
//
// Key Features:
//   - Parameterizable number of pulser instances (`N_PULSER_INST`)
//   - Register-mapped control and configuration interface per pulser
//   - Instance selection and register decode via address bits
//   - Synchronous OBI protocol handshake handling (req, gnt, rvalid, etc.)
//   - Centralized command register for starting/stopping multiple pulsers simultaneously
//
// REGISTER MAP (per instance, offset by upper address bits):
//   - 0x00 : CMD         → Start/Stop pulses (bit-encoded per instance)
//   - 0x04 : F1_CFG      → {f1_end, f1_switch}
//   - 0x08 : F2_CFG      → {f2_end, f2_switch}
//   - 0x0C : COUNT_CFG   → {stop_count, f2_count, f1_count}
//   - 0x10 : STATUS      → {ready, state}
//   - 0x14 : OUT_CTRL    → {idle_out, invert_out}
//
// Each pulser is independently configurable and drives its own `pulse_o` output.
// The wrapper tracks FSM states and readiness status from each instance,
// and handles proper decoding, storage, and routing of configuration data.
//
// Dependencies:
//   - `pulser_core.sv` (pulser logic)
//   - `common_cells/registers.svh` (flip-flop and register macros)
//
// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//-----------------------------------------------------------------------------------------------

`include "register_interface/typedef.svh"

//-----------------------------------------------------------------------------------------------
// Top-level wrapper module for multiple pulser instances
//-----------------------------------------------------------------------------------------------
module pulser #(
  parameter obi_pkg::obi_cfg_t      ObiCfg         = obi_pkg::ObiDefaultConfig,
  parameter type                    obi_req_t      = logic,
  parameter type                    obi_rsp_t      = logic,
  parameter type                    reg_req_t      = logic,
  parameter type                    reg_rsp_t      = logic,
  parameter int                     N_PULSER_INST  = 4
) (
  input  logic                      clk_i,
  input  logic                      rst_ni,

  input  obi_req_t                  obi_req_i,
  output obi_rsp_t                  obi_rsp_o,

  output logic [N_PULSER_INST-1:0]  pulse_o
);

  //-----------------------------------------------------------------------------------------------
  // Derived parameters
  //-----------------------------------------------------------------------------------------------
  localparam int PULSER_SEL_ADDR_WIDTH = (N_PULSER_INST < 2) ? 1 : $clog2(N_PULSER_INST + 1); // +1 to select general config register
  localparam int AW_CORE_REG = pulser_core_reg_pkg::BlockAw;
  
  localparam int PULSER_SEL_LOW   = AW_CORE_REG;
  localparam int PULSER_SEL_HIGH  = PULSER_SEL_LOW + PULSER_SEL_ADDR_WIDTH - 1 + 1; //  +1 to select general config register

  logic [PULSER_SEL_ADDR_WIDTH-1:0] pulser_sel;
  logic [N_PULSER_INST - 1:0]       valid_pulser_req;
  logic                             valid_general_req;


  logic [N_PULSER_INST - 1:0][2:0]  state;
  logic [N_PULSER_INST - 1:0]       start_pulse, stop_pulse;

  reg_req_t reg_req;
  reg_rsp_t reg_rsp;
  reg_req_t [N_PULSER_INST - 1:0] reg_req_mux;
  reg_rsp_t [N_PULSER_INST - 1:0] reg_rsp_mux;

  reg_req_t reg_req_general;
  reg_rsp_t reg_rsp_general;

  pulser_core_reg_pkg::pulser_core_reg2hw_t [N_PULSER_INST - 1:0] reg2hw;
  pulser_core_reg_pkg::pulser_core_hw2reg_t [N_PULSER_INST - 1:0] hw2reg;
  
  pulser_general_reg_pkg::pulser_general_reg2hw_t reg2hw_general;


  assign pulser_sel = reg_req.addr[PULSER_SEL_HIGH : PULSER_SEL_LOW];
  assign valid_pulser_req = (1 << pulser_sel) && reg_req.valid;
  assign valid_general_req = (pulser_sel == N_PULSER_INST) && reg_req.valid;

  assign reg_rsp =  (valid_general_req) ? reg_rsp_general :
                    (pulser_sel < N_PULSER_INST && reg_req.valid) ? reg_rsp_mux[pulser_sel] :
                    '0;

  periph_to_reg #(
    .AW        ( ObiCfg.AddrWidth   ),
    .DW        ( ObiCfg.DataWidth   ),
    .BW        ( 8                  ),
    .IW        ( ObiCfg.IdWidth     ),
    .req_t     ( reg_req_t          ),
    .rsp_t     ( reg_rsp_t          )
  ) i_periph_to_reg (
    .clk_i     ( clk_i              ),
    .rst_ni    ( rst_ni             ),

    .req_i     ( obi_req_i.req      ),
    .add_i     ( obi_req_i.a.addr   ),
    .wen_i     ( ~obi_req_i.a.we    ),
    .wdata_i   ( obi_req_i.a.wdata  ),
    .be_i      ( obi_req_i.a.be     ),
    .id_i      ( obi_req_i.a.aid    ),

    .gnt_o     ( obi_rsp_o.gnt      ),
    .r_rdata_o ( obi_rsp_o.r.rdata  ),
    .r_opc_o   (  ),
    .r_id_o    ( obi_rsp_o.r.rid    ),
    .r_valid_o ( obi_rsp_o.rvalid   ),

    .reg_req_o ( reg_req            ),
    .reg_rsp_i ( reg_rsp            )
  );

  for (genvar ii = 0; ii < N_PULSER_INST; ii++) begin : gen_pulser_regs

    assign reg_req_mux[ii].addr   = reg_req.addr;
    assign reg_req_mux[ii].write  = reg_req.write;
    assign reg_req_mux[ii].wdata  = reg_req.wdata;
    assign reg_req_mux[ii].wstrb  = reg_req.wstrb;
    assign reg_req_mux[ii].valid  = valid_pulser_req[ii];

    pulser_core_reg_top #(
      .reg_req_t  ( reg_req_t       ),
      .reg_rsp_t  ( reg_rsp_t       )
    ) i_pulser_core_reg_top (
      .clk_i      ( clk_i           ),
      .rst_ni     ( rst_ni          ),
      .reg_req_i  ( reg_req_mux[ii] ),
      .reg_rsp_o  ( reg_rsp_mux[ii] ),
      // To HW
      .reg2hw     ( reg2hw[ii]      ),
      .hw2reg     ( hw2reg[ii]      ),

      // Config: If 1, explicit error return for unmapped register access
      .devmode_i  ( 1'b1 )
    );
  end


  assign reg_req_general.addr   = reg_req.addr;
  assign reg_req_general.write  = reg_req.write;
  assign reg_req_general.wdata  = reg_req.wdata;
  assign reg_req_general.wstrb  = reg_req.wstrb;
  assign reg_req_general.valid  = valid_general_req;
  pulser_general_reg_top #(
    .reg_req_t  ( reg_req_t   ),
    .reg_rsp_t  ( reg_rsp_t   )
  ) i_pulser_general_reg_top (
    .clk_i      ( clk_i       ),
    .rst_ni     ( rst_ni      ),
    .reg_req_i  ( reg_req_general ),
    .reg_rsp_o  ( reg_rsp_general     ),
    // To HW
    .reg2hw     ( reg2hw_general  ),

    // Config: If 1, explicit error return for unmapped register access
    .devmode_i  ( 1'b1 )
  );

  //-----------------------------------------------------------------------------------------------
  // Pulser instantiations
  //-----------------------------------------------------------------------------------------------


  for (genvar ii = 0; ii < N_PULSER_INST; ii++) begin : gen_pulsers
    // assign start_pulse[ii]  = reg2hw_general.ctrl.start.qe[ii] & reg2hw_general.ctrl.start.q[ii];
    // assign stop_pulse[ii]   = reg2hw_general.ctrl.stop.qe[ii] & reg2hw_general.ctrl.stop.q[ii];
    assign start_pulse[ii]  = reg2hw_general.ctrl.start.qe & reg2hw_general.ctrl.start.q;
    assign stop_pulse[ii]   = reg2hw_general.ctrl.stop.qe & reg2hw_general.ctrl.stop.q;

    pulser_core i_pulser_core (
      .clk_i          ( clk_i                             ),
      .rst_ni         ( rst_ni                            ),
      .start_i        ( start_pulse[ii]                   ),
      .stop_i         ( stop_pulse[ii]                    ),
      .f1_cnt_i       ( reg2hw[ii].cfg_cnt.f1.q           ),
      .f2_cnt_i       ( reg2hw[ii].cfg_cnt.f2.q           ),
      .stop_cnt_i     ( reg2hw[ii].cfg_cnt.cnt_stop.q     ),
      .f1_end_i       ( reg2hw[ii].cfg_f1.endval.q        ),
      .f1_switch_i    ( reg2hw[ii].cfg_f1.switchval.q     ),
      .f2_end_i       ( reg2hw[ii].cfg_f2.endval.q        ),
      .f2_switch_i    ( reg2hw[ii].cfg_f2.switchval.q     ),
      .invert_out_i   ( reg2hw[ii].ctrl_out.invert_out.q  ),
      .idle_out_i     ( reg2hw[ii].ctrl_out.idle_out.q    ),
      .pulse_o        ( pulse_o[ii]                       ),
      .state_o        ( state[ii]                         )
    );
  end

endmodule
