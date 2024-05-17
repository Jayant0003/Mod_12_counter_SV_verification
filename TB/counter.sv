module Loadable_Counter(input clock,
			input Reset,
			input Load,
			input Mode,
			input [3:0] Data_in,
			output reg [3:0] Data_out);
	always @(posedge clock) begin
         //$display("pp ",Data_in);
		if(Reset)
			Data_out<=0;
		else begin
			if(Load==0 && Mode==0) begin
				if(Data_out==0)
					Data_out<=4'b1011;
				else
				Data_out<=Data_out-1;
						end
			else if(Load==0 && Mode==1) begin
				if(Data_out==4'b1011)
					Data_out<=0;
				else
					Data_out<=Data_out+1;
						    end
			else if(Load==1 && Mode==0) begin
				
				if(Data_in==4'b0)
					Data_out<=4'b1011;
				else
				  Data_out<=Data_in-1;
							end
			else if(Load==1 && Mode==1) begin
				
			    		if(Data_in==4'b1011)
					Data_out<=0;
				else
					Data_out<=Data_in+1;
				
						    end				
		
		end
	end
endmodule

interface counter_if(input bit clock);
  logic Reset;
  logic Load; 
  logic Mode;
  logic [3:0] Data_in;
  logic [3:0] Data_out;
  
  clocking wr_drv_cb @(posedge clock);
    default input #1 output #1;
    output Reset;
    output Load;
    output Data_in;
    output Mode;
  endclocking
  
  clocking wr_mon_cb @(posedge clock);
    default input #1 output #1;
	  input Reset;
	  input Load;
	  input Mode;
	  input Data_in;
  endclocking
  
  clocking rd_mon_cb @(posedge clock);
    default input #1 output #1;	
	  input Data_out;	
  endclocking
  
  modport WR_DRV_MP(clocking wr_drv_cb);
  modport WR_MON_MP(clocking wr_mon_cb);
  modport RD_MON_MP(clocking rd_mon_cb);
         
endinterface
        
package pkg;
static int no_of_transaction=80;
endpackage

import pkg::*;


class Transaction;
  rand bit Reset,Load,Mode;
  rand bit[3:0] Data_in;
   logic [3:0] Data_out;
   int trans_id;
   int up_counting;
   int down_counting;
   int load_up_counting;
   int load_down_counting;
	constraint c1{ Data_in inside {[1:11]};Reset dist {1:=30,0:=70};Load dist {1:=50,0:=50};}
 
 function void post_randomize();
   trans_id++;
   $display("ID=%0d Reset=%b Load=%b Mode=%b Din=%d",trans_id,Reset,Load,Mode,Data_in);
 endfunction
 
virtual function void display(input string message);
      $display("=============================================================");
      $display("%s",message);
      if(message=="\tRANDOMIZED DATA")
         begin
            $display("\t_______________________________");
            $display("\tTransaction No. %d",trans_id);
            $display("\t_______________________________");
         end
      $display("\tReset=%d Load=%d, Mode=%d",Reset,Load,Mode);
      $display("\tData=%d",Data_in);
      $display("\tData_out= %d",Data_out);
      $display("=============================================================");
   endfunction
	
endclass

class Generator;
	
  mailbox #(Transaction) gn2wd;
  Transaction gen_trans,data2send;
  
  
  function new(mailbox #(Transaction) gn2wd);
    this.gn2wd=gn2wd;
    gen_trans=new;
  endfunction
  
  virtual task start;
    fork
       
         for(int i=0;i<no_of_transaction;i++) begin
         assert(gen_trans.randomize());
		//$display(trans.Load," ",gen_trans.Data_in);
           data2send=new gen_trans;           
           gn2wd.put(data2send);      
         end    
      
    join_none
endtask
endclass
    
class Write_Driver;
  virtual counter_if.WR_DRV_MP wr_drv_if;
  mailbox #(Transaction) gn2wd;
  Transaction data2duv;
  
  function new(mailbox #(Transaction) gn2wd,virtual counter_if.WR_DRV_MP wr_drv_if);
    this.wr_drv_if=wr_drv_if;
    this.gn2wd=gn2wd;
endfunction
    
virtual task drive();
  @(wr_drv_if.wr_drv_cb);
  wr_drv_if.wr_drv_cb.Reset<=data2duv.Reset;
  wr_drv_if.wr_drv_cb.Load<=data2duv.Load;
  wr_drv_if.wr_drv_cb.Mode<=data2duv.Mode;
  wr_drv_if.wr_drv_cb.Data_in<=data2duv.Data_in;
  //repeat(2) @(wr_drv_if.wr_drv_cb);
  
  endtask
    
virtual task start;
  fork    
      forever begin
        gn2wd.get(data2duv);
//	$display("gn2wd ",data2duv.Load, " ",data2duv.Data_in);
        drive();
        end    
  join_none
endtask
endclass
    
class Write_Monitor;

  mailbox #(Transaction) wm2rf;
  
  Transaction trans1,data2rf;
  
  virtual counter_if.WR_MON_MP wr_mon_if;
  
  function new(virtual counter_if.WR_MON_MP wr_mon_if,mailbox #(Transaction) wm2rf);
    this.wr_mon_if=wr_mon_if;
    this.wm2rf=wm2rf;
    this.trans1=new;
  endfunction

  virtual task monitor();
    @(wr_mon_if.wr_mon_cb); begin
    trans1.Load=wr_mon_if.wr_mon_cb.Load;
    trans1.Mode=wr_mon_if.wr_mon_cb.Mode;
    trans1.Data_in=wr_mon_if.wr_mon_cb.Data_in; 
    trans1.Reset=wr_mon_if.wr_mon_cb.Reset;	 
   // repeat (2)@(wr_mon_if.wr_mon_cb);
  trans1.display("DATA FORM WRITE MONITOR");
    
  end
  
  endtask
  virtual task start;
    fork      
        forever begin
        monitor();	
        data2rf=new trans1;        
        wm2rf.put(data2rf);
    //  $display("wm2rf  Din=%0d Reset=%b Load=%b Mode=%b",data2send.Data_in,data2send.Reset,data2send.Load,data2send.Mode);	
        end
      
    join_none
  endtask
endclass
    
class Read_Monitor;
  mailbox #(Transaction) rm2sb;
  virtual counter_if.RD_MON_MP rd_mon_if;
  Transaction rmdata,data2sb;
  function new(virtual counter_if.RD_MON_MP rd_mon_if,mailbox #(Transaction) rm2sb);
    this.rd_mon_if=rd_mon_if;
    this.rm2sb=rm2sb;
    rmdata=new;
  endfunction
virtual   task monitor;
    @(rd_mon_if.rd_mon_cb);
        rmdata.Data_out=rd_mon_if.rd_mon_cb.Data_out;
	 rmdata.display("DATA FROM READ MONITOR");
  endtask
  
  virtual task start;
    fork 
      
        forever
          begin
            monitor;
            data2sb=new rmdata;
            rm2sb.put(data2sb);
           //$display("rm2sb   DUV_Data_out>>>",data2send.Data_out);
          end
      
    join_none
	endtask
endclass
    
class Ref_Model;
 // static bit Reset,Load,Mode;
 
  static bit [3:0] Data_out1;
  
  mailbox #(Transaction) wm2rf,rf2sb;
  Transaction wmdata;
  
  function new(  mailbox #(Transaction) wm2rf,rf2sb);
    this.wm2rf=wm2rf;
    this.rf2sb=rf2sb;    
  endfunction


  task counter(Transaction wmdata); begin
   	if(wmdata.Reset)
			Data_out1<=0;
		else begin
			if(wmdata.Load==0 && wmdata.Mode==0) begin
				if(Data_out1==0)
					Data_out1<=4'b1011;
				else
				Data_out1<=Data_out1-1;
						end
			else if(wmdata.Load==0 && wmdata.Mode==1) begin
				if(Data_out1==4'b1011)
					Data_out1<=0;
				else
					Data_out1<=Data_out1+1;
						    end
			else if(wmdata.Load==1 && wmdata.Mode==0) begin
				
				if(wmdata.Data_in==4'b0)
					Data_out1<=4'b1011;
				else
				  Data_out1<=wmdata.Data_in-1;
							end
			else if(wmdata.Load==1 && wmdata.Mode==1) begin
				
				if(wmdata.Data_in==4'b1011)
					Data_out1<=0;
				else
					Data_out1<=wmdata.Data_in+1;
				
						    end				
		
		end
end
  endtask  
  virtual task start;
    fork          
            forever begin
                  wm2rf.get(wmdata);  
                  //$display("wm2rf  Din=%0d Reset=%b Load=%b Mode=%b",trans.Data_in,trans.Reset,trans.Load,trans.Mode);       
                  counter(wmdata);
	    	          wmdata.Data_out=Data_out1;
                  wmdata.display("DATA FROM REF MODEL");    
                  rf2sb.put(wmdata);	
          end   	
    join_none
    
  endtask
endclass

class SB;
	
  event DONE;
  int data_verified;
  mailbox #(Transaction) rf2sb,rm2sb;
  Transaction rf_data,rm_data,cov_data;
  function new(  mailbox #(Transaction) rf2sb,rm2sb);
    this.rf2sb=rf2sb;
    this.rm2sb=rm2sb;
    counter_coverage=new;
  endfunction
  
  virtual task start;
    fork
      begin
        forever begin
          rf2sb.get(rf_data);
          rm2sb.get(rm_data);
	  $display("rf_dout ",rf_data.Data_out," rm_dout ",rm_data.Data_out," rf_din ",rf_data.Data_in," rf_load ",rf_data.Load," rf_mode ",rf_data.Mode);
          if(rf_data.Data_out==rm_data.Data_out)begin
          $display("<<<<DATA MATCHED>>>\n");
          cov_data=new rf_data;
            counter_coverage.sample();
            data_verified++;
            if(data_verified>=no_of_transaction)
              ->DONE;
            
          end
        else begin
          $display("<<<<DATA MISMATCHED>>>\n");
	  
	end
      end
      end
    join_none
  endtask
  
  covergroup counter_coverage;
    option.per_instance=1;
    RESET: coverpoint cov_data.Reset{ bins rst={0};}
    LOAD: coverpoint cov_data.Load{bins L0={1};}
                                  // bins L1={1};}
    MODE: coverpoint cov_data.Mode{bins M0={0};
                                   bins M1={1};}
    DATA_OUT: coverpoint cov_data.Data_out{bins D0={1,2,3};
					   bins D1={4,5,6};
				           bins D2={7,8,9};
					   bins D3={11};}
    CROSS1: cross RESET,LOAD,MODE,DATA_OUT;
    
  endgroup
  
endclass

class Env;
  virtual counter_if.WR_DRV_MP wr_drv_if;
  virtual counter_if.WR_MON_MP wr_mon_if;
  virtual counter_if.RD_MON_MP rd_mon_if;
  mailbox #(Transaction) gn2wd=new;
  mailbox #(Transaction) wm2rf=new;
  mailbox #(Transaction) rm2sb=new;
  mailbox #(Transaction) rf2sb=new;
  
  Generator gen;
  Write_Driver wr_drv;
  Read_Monitor rd_mon;
  Write_Monitor wr_mon;
  Ref_Model rf_m;
  SB sb;
  
  function new(virtual counter_if.WR_DRV_MP wr_drv_if,
               virtual counter_if.WR_MON_MP wr_mon_if,
               virtual counter_if.RD_MON_MP rd_mon_if);
    this.wr_drv_if=wr_drv_if;
    this.wr_mon_if=wr_mon_if;
    this.rd_mon_if=rd_mon_if;
  endfunction
    
 virtual task build;
	gen=new(gn2wd);
     wr_drv=new(gn2wd,wr_drv_if);
    wr_mon=new(wr_mon_if,wm2rf);
    rd_mon=new(rd_mon_if,rm2sb);
    rf_m=new(wm2rf,rf2sb);
    sb=new(rf2sb,rm2sb);
  endtask

  virtual task start;
    gen.start;    
    wr_drv.start;
    wr_mon.start;   
     //$display("a ",wr_mon_if.wr_mon_cb.Data_in);
    rd_mon.start;
    rf_m.start;
    sb.start;  
  endtask
  
  virtual task stop;
    wait(sb.DONE.triggered);
  endtask
  
  virtual task run;
    start;
    stop;
   // sb.report;
  endtask
  
  
endclass



class Test;
 
  Env env;
  virtual counter_if.WR_DRV_MP wr_drv_if;
  virtual counter_if.WR_MON_MP wr_mon_if;
  virtual counter_if.RD_MON_MP rd_mon_if;
   
  
  function new(virtual counter_if.WR_DRV_MP wr_drv_if,
               virtual counter_if.WR_MON_MP wr_mon_if,
               virtual counter_if.RD_MON_MP rd_mon_if);
    this.wr_drv_if=wr_drv_if;
    this.wr_mon_if=wr_mon_if;
    this.rd_mon_if=rd_mon_if;
    env=new(wr_drv_if,wr_mon_if,rd_mon_if);
  endfunction
  
virtual  task build;
    env.build;
  endtask
 virtual task run;
 	env.run;
  endtask
  
endclass



module top;
	import pkg::*;
  reg clock;
  parameter period=10;
  counter_if IF(clock);
  
  Loadable_Counter DUT(clock, IF.Reset,IF.Load,IF.Mode,IF.Data_in,IF.Data_out);
  
  Test test;
  
  initial begin
    clock=0;
    forever #(period/2) clock=~clock;
  end
  
  initial begin
    test=new(IF,IF,IF);
    test.build;
    test.run;
   $finish;
  end
  
endmodule


  
    
  
  /*
// To get coverage report
1. vcs -sverilog filename.sv -debug_access+all -kdb
2. ./simv -cm_dir ./cov
3. urg -dir cov -format both
4. gvim urgReport/grp*.txt

               (or)

1. vcs -sverilog filename.sv -debug_access+all -kdb
2. ./simv -cm_dir ./cov
3. urg -dir cov -format both
4. firefox urgReport/grp0.html
*/
/*
module tb;
reg [3:0] Data_in;
reg Load,Mode,Clock,Reset;
wire [3:0] Data_out;
Loadable_Counter DUT(Clock,Reset,Load,Mode,Data_in,Data_out);

initial begin
	{Clock,Reset,Load,Mode,Data_in}=0;
	forever #1 Clock=~Clock;
end

task reset; begin
 @(negedge Clock)
	Reset=1'b1;
 @(negedge Clock)
	Reset=1'b0;
end endtask

task Drive(input load, input mode); begin
 @(negedge Clock) begin
 Load=load;
 Mode=mode;
end
end endtask
task Drive1(input load,input mode,input [3:0]data); begin
 @(negedge Clock) begin
 Data_in=data;
 Load=load;
 Mode=mode;
end
end endtask

initial begin
  reset;
 #1;
  Drive(0,0);
 #2; 
  Drive(0,1);
 #2;
  Drive1(1,0,0);
	
 #2;
  Drive1(1,0,10);
 #2;
  Drive1(1,1,4'b1000);
 #2;
  Drive1(1,1,4'b1100);
 #2;
  Drive(0,1);
 #2;
  Drive(0,0);
 #4;
 $finish;

end
initial 
  $monitor("%t clk=%b Reset=%b Load=%b Mode=%b Din=%b Dout=%b",$time,Clock,Reset,Load,Mode,Data_in,Data_out);



endmodule
*/
  
