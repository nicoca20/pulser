//-----------------------------------------------------------------------------------------------
// File        : pulser.sv
// Author      : Nico Canzani <ncanzani@student.ethz.ch>
// Description : Top-Level Wrapper for multiple Pulse Generators
//
// This module integrates multiple instances of the `pulser_core` module and exposes
// register interfaces over the OBI (Open Bus Interface) protocol.
//
// Key Features:
//   - Parameterizable number of pulser instances (`N_PULSER_INST`)
//   - Register-mapped control and configuration interface per pulser
//   - Instance selection and register decode via address bits
//   - Synchronous OBI protocol handshake handling (req, gnt, rvalid, etc.)
//   - Centralized command register for starting/stopping multiple pulsers simultaneously
//   - Enables clock gating for each pulser instance to save power
//
// REGISTER MAP for pulser_core (32 Bit, starting at LSB):
//   - 0x00 : F1_CFG      : {f1_end, f1_switch}               16 + 16 Bit
//   - 0x04 : F2_CFG      : {f2_end, f2_switch}               16 + 16 Bit
//   - 0x08 : COUNT_CFG   : {stop_count, f2_count, f1_count}  8 + 8 + 8 Bit
//   - 0x0c : STATUS      : {state, ready}                    3 + 1 Bit
//   - 0x10 : OUT_CTRL    : {idle_out, invert_out}            1 + 1 Bit
//
// Each pulser is independently configurable and drives its own `pulse_o` output.
// The wrapper tracks FSM states and readiness status from each instance,
// and handles proper decoding, storage, and routing of configuration data.
//
// Dependencies:
//   - `pulser_core.sv` (pulser logic)
//   - `common_cells/registers.svh` (flip-flop and register macros)
//   - `obi_pkg.sv` (Open Bus Interface definitions)
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

  // N_PULSER_INST + 1 to select general config register as well
  localparam int BLOCK_SEL_ADDR_WIDTH = (N_PULSER_INST < 2) ? 1 : $clog2(N_PULSER_INST + 1);
  localparam int AW_CORE_REG = pulser_core_reg_pkg::BlockAw;
  localparam int AW_GENERAL_REG = pulser_general_reg_pkg::BlockAw;

  //-----------------------------------------------------------------------------------------------
  // Wires to demux the pulser obi requests internally
  //-----------------------------------------------------------------------------------------------

  logic [BLOCK_SEL_ADDR_WIDTH-1:0]  block_sel;
  logic [N_PULSER_INST - 1:0]       valid_pulser_req;
  logic                             valid_general_req;

  reg_req_t reg_req;
  reg_rsp_t reg_rsp;
  reg_req_t [N_PULSER_INST - 1:0] reg_req_mux;
  reg_rsp_t [N_PULSER_INST - 1:0] reg_rsp_mux;

  reg_req_t reg_req_general;
  reg_rsp_t reg_rsp_general;

  pulser_core_reg_pkg::pulser_core_reg2hw_t [N_PULSER_INST - 1:0] reg2hw;
  pulser_core_reg_pkg::pulser_core_hw2reg_t [N_PULSER_INST - 1:0] hw2reg;
  
  pulser_general_reg_pkg::pulser_general_reg2hw_t reg2hw_general;

  //-----------------------------------------------------------------------------------------------
  // Wires to control / read states of each pulser.
  //-----------------------------------------------------------------------------------------------

  logic [N_PULSER_INST - 1:0][2:0]  state;
  logic [N_PULSER_INST - 1:0]       ready;
  logic [N_PULSER_INST - 1:0]       start_pulse, stop_pulse;

  //-----------------------------------------------------------------------------------------------
  // Wires to enable / disable each Pulser.
  //-----------------------------------------------------------------------------------------------
  logic [N_PULSER_INST - 1:0]       enable_clk;
  logic [N_PULSER_INST - 1:0]       clk_pulser;

  //-----------------------------------------------------------------------------------------------
  // Periph to reg instantiation to connect OBI to the register files.
  //-----------------------------------------------------------------------------------------------

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
    .r_opc_o   ( obi_rsp_o.r.err    ),
    .r_id_o    ( obi_rsp_o.r.rid    ),
    .r_valid_o ( obi_rsp_o.rvalid   ),

    .reg_req_o ( reg_req            ),
    .reg_rsp_i ( reg_rsp            )
  );

  // Set unused wire to avoid any "Wire has no driver" warnings
  assign obi_rsp_o.r.r_optional = 1'b0;

  //-----------------------------------------------------------------------------------------------
  // Pulser General Register instantiation.
  // start / stop and enable pulser from here.
  //-----------------------------------------------------------------------------------------------

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
  // Pulser Register instantiations
  //-----------------------------------------------------------------------------------------------

  for (genvar ii = 0; ii < N_PULSER_INST; ii++) begin : gen_pulser_regs
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

  //-----------------------------------------------------------------------------------------------
  // Pulser clkgate instantiations
  //-----------------------------------------------------------------------------------------------

  for (genvar ii = 0; ii < N_PULSER_INST; ii++) begin : gen_pulser_clkgate
    tc_clk_gating #(
      .IS_FUNCTIONAL    ( 1'b0                )
    ) i_tc_clk_gating (
      .clk_i            ( clk_i               ),
      .en_i             ( enable_clk[ii]      ),
      .test_en_i        ( 1'b0                ),
      .clk_o            ( clk_pulser[ii]      )
    );
  end

  assign enable_clk = reg2hw_general.cfg.q[N_PULSER_INST - 1:0];

  //-----------------------------------------------------------------------------------------------
  // Pulser instantiations
  //-----------------------------------------------------------------------------------------------

  for (genvar ii = 0; ii < N_PULSER_INST; ii++) begin : gen_pulser_cores

    pulser_core i_pulser_core (
      .clk_i          ( clk_pulser[ii]                    ),
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
      .state_o        ( state[ii]                          )
    );
  end

  //-----------------------------------------------------------------------------------------------
  // Pulser_core inputs and outputs
  // Connect pulser_core signals not comming directly from reg2hw
  //-----------------------------------------------------------------------------------------------
  always_comb begin
    for (int ii = 0; ii < N_PULSER_INST; ii++) begin
      start_pulse[ii]           = reg2hw_general.ctrl.start.qe & reg2hw_general.ctrl.start.q[ii];
      stop_pulse[ii]            = reg2hw_general.ctrl.stop.qe & reg2hw_general.ctrl.stop.q[ii];

      hw2reg[ii].status.state.d = state[ii];
      hw2reg[ii].status.state.de = 1'b1; // Pass state to FF all the time
    end
  end

  //-----------------------------------------------------------------------------------------------
  // Router for register requests
  // This block decodes the address to route the register request to the correct pulser instance
  // and the general config register.
  // It uses the `block_sel` bits to determine which pulser instance or general config register
  // should handle the request.
  //-----------------------------------------------------------------------------------------------

  assign block_sel = reg_req.addr[AW_CORE_REG + BLOCK_SEL_ADDR_WIDTH - 1 : AW_CORE_REG];

  always_comb begin : router_addr_decode
    reg_req_mux = '0;
    reg_req_general = '0;

    if (block_sel == N_PULSER_INST) begin
      // If block_sel is equal to N_PULSER_INST, it is the general config register
      reg_req_general = reg_req;
      reg_req_general.addr = reg_req.addr[AW_GENERAL_REG - 1:0];
      reg_rsp = reg_rsp_general;
    end else if (block_sel < N_PULSER_INST) begin
      // If block_sel is less than N_PULSER_INST, it is a pulser register
      reg_req_mux[block_sel] = reg_req;
      reg_req_mux[block_sel].addr = reg_req.addr[AW_CORE_REG - 1:0];
      reg_rsp = reg_rsp_mux[block_sel];
    end
  end

  //-----------------------------------------------------------------------------------------------
  // READY signal: high when pulser is in IDLE or DONE state
  //-----------------------------------------------------------------------------------------------
  localparam logic [2:0] STATE_IDLE = 3'd0;
  localparam logic [2:0] STATE_DONE = 3'd4;

  always_comb begin
    for (int i = 0; i < N_PULSER_INST; i++) begin
      ready[i] = (state[i] == STATE_IDLE) || (state[i] == STATE_DONE);
      hw2reg[i].status.ready.d = ready[i];
      hw2reg[i].status.ready.de = 1'b1; // Pass ready bit to FF all the time
    end
  end

endmodule
