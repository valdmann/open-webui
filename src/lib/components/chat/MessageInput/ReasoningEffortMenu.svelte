<script lang="ts">
	import { getContext } from 'svelte';

	import Dropdown from '$lib/components/common/Dropdown.svelte';
	import DropdownMenu from '$lib/components/common/DropdownMenu.svelte';
	import Tooltip from '$lib/components/common/Tooltip.svelte';
	import LightBulb from '$lib/components/icons/LightBulb.svelte';

	const i18n = getContext('i18n');

	export let value: string | null = null;
	export let onChange: Function = () => {};

	const levels = [
		{ value: 'none', label: 'None' },
		{ value: 'minimal', label: 'Minimal' },
		{ value: 'low', label: 'Low' },
		{ value: 'medium', label: 'Medium' },
		{ value: 'high', label: 'High' },
		{ value: 'xhigh', label: 'X-High' },
		{ value: 'max', label: 'Max' }
	];

	let dropdown: Dropdown;

	const select = (effort: string | null) => {
		onChange(effort);
		dropdown.close();
	};

	$: selected = levels.find((level) => level.value === value);

	const triggerClass =
		'flex items-center gap-1.5 rounded-lg px-2 py-1 text-[0.8125rem] font-normal text-gray-600 transition-colors duration-100 hover:bg-gray-50/40 hover:text-gray-700 dark:text-gray-300 dark:hover:bg-gray-800/40 dark:hover:text-gray-200';
	const itemClass = (active: boolean) =>
		`flex w-full justify-between gap-2 items-center h-[1.6875rem] px-2 text-[0.8125rem] font-normal cursor-pointer rounded-xl ${
			active ? 'bg-gray-50/40 dark:bg-gray-800/40' : 'hover:bg-gray-50/40 dark:hover:bg-gray-800/40'
		}`;
</script>

<Dropdown bind:this={dropdown} align="end">
	<Tooltip
		content={$i18n.t(
			'Constrains effort on reasoning for reasoning models. Only applicable to reasoning models from specific providers that support reasoning effort.'
		)}
		placement="top"
	>
		<button type="button" class={triggerClass} aria-label={$i18n.t('Reasoning Effort')}>
			<LightBulb className="size-4" strokeWidth="1.5" />
			<span class="truncate max-w-[6rem]">
				{selected ? $i18n.t(selected.label) : $i18n.t('Effort')}
			</span>
		</button>
	</Tooltip>

	<div slot="content">
		<DropdownMenu className="min-w-40 max-w-40 scrollbar-thin">
			<div class="flex items-center px-3 py-1">
				<span
					class="text-[0.625rem] font-normal text-gray-400 dark:text-gray-500 uppercase tracking-wider"
				>
					{$i18n.t('Reasoning Effort')}
				</span>
			</div>

			<button type="button" class={itemClass(!value)} on:click={() => select(null)}>
				<div class="flex flex-1 gap-2 items-center truncate">
					<span class="truncate">{$i18n.t('Default')}</span>
				</div>
				{#if !value}
					<div class="shrink-0 text-emerald-600 dark:text-emerald-400">
						<svg
							xmlns="http://www.w3.org/2000/svg"
							viewBox="0 0 20 20"
							fill="currentColor"
							class="size-3.5"
						>
							<path
								fill-rule="evenodd"
								d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
								clip-rule="evenodd"
							/>
						</svg>
					</div>
				{/if}
			</button>

			{#each levels as level}
				<button
					type="button"
					class={itemClass(value === level.value)}
					on:click={() => select(level.value)}
				>
					<div class="flex flex-1 gap-2 items-center truncate">
						<span class="truncate">{$i18n.t(level.label)}</span>
					</div>
					{#if value === level.value}
						<div class="shrink-0 text-emerald-600 dark:text-emerald-400">
							<svg
								xmlns="http://www.w3.org/2000/svg"
								viewBox="0 0 20 20"
								fill="currentColor"
								class="size-3.5"
							>
								<path
									fill-rule="evenodd"
									d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
									clip-rule="evenodd"
								/>
							</svg>
						</div>
					{/if}
				</button>
			{/each}
		</DropdownMenu>
	</div>
</Dropdown>
