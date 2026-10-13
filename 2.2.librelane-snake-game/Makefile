TOOL=librelane
RUN=runs


flow:
	$(TOOL) --manual-pdk config.json 

view:
	$(TOOL) --manual-pdk config.json --last-run --flow OpenInOpenROAD

clean:
	rm -rf $(RUN)